#!/bin/sh

echo '--> mdv-scripts/build-packages/cooker: openmandriva-arm.sh'

# mdv example:
# git_project_address="https://abf.rosalinux.ru/import/plasma-applet-stackfolder.git"
# commit_hash="bfe6d68cc607238011a6108014bdcfe86c69456a"
git_project_address="$GIT_PROJECT_ADDRESS"
commit_hash="$COMMIT_HASH"

uname="$UNAME"
email="$EMAIL"
platform_name="$PLATFORM_NAME"
platform_arch="$ARCH"
extra_cfg_options="$EXTRA_CFG_OPTIONS"
extra_build_src_rpm_options="$EXTRA_BUILD_SRC_RPM_OPTIONS"
extra_build_rpm_options="$EXTRA_BUILD_RPM_OPTIONS"

echo $git_project_address | awk '{ gsub(/\:\/\/.*\:\@/, "://[FILTERED]@"); print }'
echo $commit_hash
echo $uname
echo $email

archives_path="/home/vagrant/archives"
results_path="/home/vagrant/results"
tmpfs_path="/home/vagrant/tmpfs"
project_path="$tmpfs_path/project"
rpm_build_script_path=`pwd`

# create SPECS folder and move *.spec
mkdir $tmpfs_path/SPECS
mv $project_path/*.spec $tmpfs_path/SPECS/
# Check count of *.spec files (should be one)
cd $tmpfs_path/SPECS
x=`ls -1 | grep '.spec$' | wc -l | sed 's/^ *//' | sed 's/ *$//'`
spec_name=`ls -1 | grep '.spec$'`
if [ $x -eq '0' ] ; then
  echo '--> There are no spec files in repository.'
  exit 1
else
  if [ $x -ne '1' ] ; then
    echo '--> There are more than one spec file in repository.'
    exit 1
  fi
fi

#create SOURCES folder and move src
mkdir $tmpfs_path/SOURCES
mv $project_path/* $tmpfs_path/SOURCES/

# Init folders for building src.rpm
cd $archives_path
src_rpm_path=$archives_path/SRC_RPM
mkdir $src_rpm_path

rpm_path=$archives_path/RPM
mkdir $rpm_path

config_dir=/etc/mock-urpm/
# Change output format for mock-urpm
sed '17c/format: %(message)s' $config_dir/logging.ini > ~/logging.ini
sudo mv -f ~/logging.ini $config_dir/logging.ini

# Init config file
EXTRA_CFG_OPTIONS="$extra_cfg_options" \
  UNAME=$uname \
  EMAIL=$email \
  RPM_BUILD_SCRIPT_PATH=$rpm_build_script_path \
  CONFIG_DIR=$config_dir \
  CONFIG_NAME='openmandriva' \
  PLATFORM_ARCH=$platform_arch \
  PLATFORM_NAME=$platform_name \
  /bin/bash $rpm_build_script_path/init_cfg_config.sh

# prepare ARM stuff
echo '--> Load binfmt_misc kernel module'
if [ ! -d /proc/sys/fs/binfmt_misc ]; then
   sudo /sbin/modprobe binfmt_misc
fi
if [ ! -f /proc/sys/fs/binfmt_misc/register ]; then
   sudo mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
fi

echo '--> install ARM-related env'
sudo sh -c "echo '$platform_arch-mandriva-linux-gnueabi' > /etc/rpm/platform"
sudo sh -c "echo ':arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-wrapper:' > /proc/sys/fs/binfmt_misc/register"


# copy qemu binaries
# it is big ugly hack
# but i do now know another proper way
# experiments with setup.spec was not successful

(while [ ! -e  $tmpfs_path/openmandriva-2013.0-$platform_arch/root/usr/bin/ ]
  do sleep 1;done
  sudo cp $rpm_build_script_path/cooker/qemu*  $tmpfs_path/openmandriva-2013.0-$platform_arch/root/usr/bin/) &
  subshellpid=$!

# Build src.rpm
echo '--> Build src.rpm'
mock-urpm --buildsrpm --spec $tmpfs_path/SPECS/$spec_name --sources $tmpfs_path/SOURCES/ --resultdir $src_rpm_path --configdir $config_dir -v --no-cleanup-after $extra_build_src_rpm_options
# Save exit code
rc=$?
kill $subshellpid
echo '--> Done.'

# Move all logs into the results dir.
function move_logs {
  prefix=$2
  for file in $1/*.log ; do
    name=`basename $file`
    if [[ "$name" =~ .*\.log$ ]] ; then
      echo "--> mv $file $results_path/$prefix-$name"
      mv $file "$results_path/$prefix-$name"
    fi
  done
}

move_logs $src_rpm_path 'src-rpm'

# Check exit code after build
if [ $rc != 0 ] ; then
  echo '--> Build failed: mock-urpm encountered a problem.'
  exit 1
fi

# Build rpm
cd $src_rpm_path
src_rpm_name=`ls -1 | grep 'src.rpm$'`
echo '--> Building rpm...'
mock-urpm $src_rpm_name --resultdir $rpm_path -v --no-cleanup-after --no-clean $extra_build_rpm_options
# Save exit code
rc=$?
echo '--> Done.'

# Save results
# mv $tmpfs_path/SPECS $archives_path/
# mv $tmpfs_path/SOURCES $archives_path/

# Remove src.rpm from RPM dir
src_rpm_name=`ls -1 $rpm_path/ | grep 'src.rpm$'`
if [ "$src_rpm_name" != '' ] ; then
  rm $rpm_path/*.src.rpm
fi

r=`head -1 $config_dir/default.cfg |
  sed -e "s/config_opts//g" |
  sed -e "s/\[//g" |
  sed -e "s/\]//g" |
  sed -e "s/root//g" |
  sed -e "s/=//g" |
  sed -e "s/'//g"|
  sed -e "s/ //g"`
chroot_path=$tmpfs_path/$r/root
echo '--> Checking internet connection...'
echo '--> We cannot check internet connection'
echo '--> because in qemu this function not implemented'
#sudo chroot $chroot_path ping -c 1 google.com

# Tests
test_log=$results_path/tests.log
test_root=$tmpfs_path/test-root
test_code=0
rpm -qa --queryformat "%{name}-%{version}-%{release}.%{arch}.%{disttag}%{distepoch}\n" --root $chroot_path >> $results_path/rpm-qa.log
if [ $rc == 0 ] ; then
  ls -la $rpm_path/ >> $test_log
  mkdir $test_root
  rpm -q --queryformat "%{name}-%{version}-%{release}.%{arch}.%{disttag}%{distepoch}\n" urpmi
  sudo mount -obind $rpm_path/ $tmpfs_path/openmandriva-2013.0-$platform_arch/root/tmp/
  sudo chroot $tmpfs_path/openmandriva-2013.0-$platform_arch/root/ /bin/bash --init-file /etc/bashrc -i -c "urpmi -v --debug --no-verify --no-suggests --test --ignorearch --noscripts /tmp/*.rpm --auto && exit" >> $test_log 2>&1
  test_code=$?
  echo 'Test code output: ' $test_code >> $test_log 2>&1
  sudo umount $tmpfs_path/openmandriva-2013.0-$platform_arch/root/tmp/
  rm -rf $test_root
fi

if [ $rc == 0 ] && [ $test_code == 0 ] ; then
  ls -la $src_rpm_path/ >> $test_log
  mkdir $test_root
  sudo mount -obind $src_rpm_path/  $tmpfs_path/openmandriva-2013.0-$platform_arch/root/tmp/
  sudo chroot $tmpfs_path/openmandriva-2013.0-$platform_arch/root/ /bin/bash --init-file /etc/bashrc -i -c "urpmi -v --debug --no-verify --test --buildrequires /tmp/*.src.rpm && exit" >> $test_log 2>&1
  test_code=$?
  echo 'Test code output: ' $test_code >> $test_log 2>&1
  sudo umount $tmpfs_path/openmandriva-2013.0-$platform_arch/root/tmp/
  rm -rf $test_root
fi

if [ $rc != 0 ] || [ $test_code != 0 ] ; then
  tree $chroot_path/builddir/build/ >> $results_path/chroot-tree.log
fi

# Umount tmpfs
cd /
# sudo umount -l $tmpfs_path
rm -rf $tmpfs_path


move_logs $rpm_path 'rpm'

# Check exit code after build
if [ $rc != 0 ] ; then
  echo '--> Build failed!!!'
  exit 1
fi

# Generate data for container
c_data=$results_path/container_data.json
echo '[' > $c_data
for rpm in $rpm_path/*.rpm $src_rpm_path/*.src.rpm ; do
  name=`rpm -qp --queryformat %{NAME} $rpm`
  if [ "$name" != '' ] ; then
    fullname=`basename $rpm`
    epoch=`rpm -qp --queryformat %{EPOCH} $rpm`
    version=`rpm -qp --queryformat %{VERSION} $rpm`
    release=`rpm -qp --queryformat %{RELEASE} $rpm`
    sha1=`sha1sum $rpm | awk '{ print $1 }'`

    echo '{' >> $c_data
    echo "\"fullname\":\"$fullname\","  >> $c_data
    echo "\"sha1\":\"$sha1\","          >> $c_data
    echo "\"name\":\"$name\","          >> $c_data
    echo "\"epoch\":\"$epoch\","        >> $c_data
    echo "\"version\":\"$version\","    >> $c_data
    echo "\"release\":\"$release\""     >> $c_data
    echo '},' >> $c_data
  fi
done
# Add '{}'' because ',' before
echo '{}' >> $c_data
echo ']' >> $c_data

# Move all rpms into results folder
echo "--> mv $rpm_path/*.rpm $results_path/"
mv $rpm_path/*.rpm $results_path/
echo "--> mv $src_rpm_path/*.rpm $results_path/"
mv $src_rpm_path/*.rpm $results_path/

# Remove archives folder
rm -rf $archives_path

# Cleanup ARM-releated hacks
sudo rm -f /etc/rpm/platform

# Check exit code after testing
if [ $test_code != 0 ] ; then
  echo '--> Test failed, see: tests.log'
  exit 5
fi
echo '--> Build has been done successfully!'
exit 0
