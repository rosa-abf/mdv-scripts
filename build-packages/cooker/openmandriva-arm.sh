#!/bin/sh

echo '--> mdv-scripts/build-packages: build.sh'

# mdv example:
# git_project_address="https://abf.rosalinux.ru/import/plasma-applet-stackfolder.git"
# commit_hash="bfe6d68cc607238011a6108014bdcfe86c69456a"
git_project_address="$GIT_PROJECT_ADDRESS"
commit_hash="$COMMIT_HASH"

uname="$UNAME"
email="$EMAIL"
#available arches armv7hl armv7l
platform_name="$PLATFORM_NAME"
platform_arch="$ARCH"

echo $git_project_address | awk '{ gsub(/\:\/\/.*\:\@/, "://[FILTERED]@"); print }'
echo $commit_hash
echo $uname
echo $email

archives_path="/home/vagrant/archives"
results_path="/home/vagrant/results"
tmpfs_path="/home/vagrant/tmpfs"
project_path="$tmpfs_path/project"
rpm_build_script_path=`pwd`

#fix bug server certificate verification failed
export GIT_SSL_NO_VERIFY=1

# TODO: build changelog

# create SPECS folder and move *.spec
sudo mkdir -p  $tmpfs_path/root/rpmbuild/SPECS
sudo mv $project_path/*.spec $tmpfs_path/root/rpmbuild/SPECS/
# create SPECS folder and move *.spec
mkdir $tmpfs_path/SPECS
mv $project_path/*.spec $tmpfs_path/SPECS/
# Check count of *.spec files (should be one)
cd $project_path/SPECS
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
sudo mkdir -p $tmpfs_path/root/rpmbuild/SOURCES/
sudo mv $project_path/* $tmpfs_path/root/rpmbuild/SOURCES/

# Init folders for building src.rpm
cd $archives_path
src_rpm_path=$archives_path/SRC_RPM
mkdir $src_rpm_path

rpm_path=$archives_path/RPM
mkdir $rpm_path


config_name="openmandriva-$platform_arch.cfg"
config_dir=/etc/mock-urpm/
sudo sh -c "echo '$platform_arch-mandriva-linux-gnueabi' > /etc/rpm/platform"
sudo sh -c "echo echo ':arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-wrapper:' > /proc/sys/fs/binfmt_misc/register"

# Init config file
default_cfg=$rpm_build_script_path/configs/default.cfg
cp $rpm_build_script_path/configs/$config_name $default_cfg
media_list=/home/vagrant/container/media.list

echo "config_opts['macros']['%packager'] = '$uname <$email>'" >> $default_cfg

echo 'config_opts["urpmi_media"] = {' >> $default_cfg
first='1'
while read CMD; do
  name=`echo $CMD | awk '{ print $1 }'`
  url=`echo $CMD | awk '{ print $2 }'`
  if [ "$first" == '1' ] ; then
    echo "\"$name\": \"$url\"" >> $default_cfg
    first=0
  else
    echo ", \"$name\": \"$url\"" >> $default_cfg
  fi
done < $media_list
echo '}' >> $default_cfg


sudo rm -rf $config_dir/default.cfg
sudo ln -s $default_cfg $config_dir/default.cfg

#Build src.rpm in cross chroot
echo "--> Create chroot"
sudo /usr/sbin/urpmi.addmedia --urpmi-root $tmpfs_path main http://abf-downloads.rosalinux.ru/$platform_name/repository/$platform_arch/main/release/ && sudo /usr/sbin/urpmi --noscripts --no-suggests --no-verify-rpm --ignorearch --root $tmpfs_path --urpmi-root $tmpfs_path --auto basesystem-minimal rpm-build make urpmi
sudo cp $rpm_build_script_path/cooker/qemu* $tmpfs_path/usr/bin/
sudo cp /etc/resolv.conf $tmpfs_path/etc/resolv.conf
sudo mount -obind /dev/ $tmpfs_path/dev
sudo mount -obind /proc/ $tmpfs_path/proc
sudo mount -obind /sys/ $tmpfs_path/sys
echo "-->> Chroot is done"
sudo chmod -R 777 $tmpfs_path/root/rpmbuild
sudo chown -R root:root $tmpfs_path/root/rpmbuild
sudo chroot $tmpfs_path/ /bin/bash --init-file /etc/bashrc -i  -c "/usr/bin/rpmbuild -bs -v --nodeps  /root/rpmbuild/SPECS/$spec_name && exit"
rc=$?


#sudo  build.py  -s $spec_name --sources $tmpfs_path/SOURCES/ --o $src_rpm_path
# Save exit code

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


# Check exit code after build
if [ $rc != 0 ] ; then
  echo '--> Build failed: mock-urpm encountered a problem.'
  exit 1
fi

# Build rpm
src_rpm_name=`sudo ls $tmpfs_path/root/rpmbuild/SRPMS/ -1 | grep 'src.rpm'`
echo $src_rpm_name
echo '--> Building rpm...'
export_list="gl_cv_func_printf_enomem=yes FORCE_UNSAFE_CONFIGURE=1 ac_cv_path_MSGMERGE=/usr/bin/msgmerge ac_cv_javac_supports_enums=yes"
sudo chroot $tmpfs_path/ /bin/bash --init-file /etc/bashrc -i -c "urpmi --buildrequires --ignorearch --auto --no-verify-rpm /root/rpmbuild/SPECS/$spec_name && exit"
sudo chroot $tmpfs_path/ /bin/bash --init-file /etc/bashrc -i -c " export $export_list;/usr/bin/rpmbuild --without check --target=$platform_arch -ba -v /root/rpmbuild/SPECS/$spec_name"


#mock $src_rpm_name --resultdir $rpm_path -v --no-cleanup
# Save exit code
rc=$?
echo '--> Done.'

echo '--> Get result.'
sudo sh -c "mv  $tmpfs_path/root/rpmbuild/RPMS/$platform_arch/*.rpm /home/vagrant/rpms/"
sudo sh -c "mv  $tmpfs_path/root/rpmbuild/RPMS/noarch/*.rpm /home/vagrant/rpms/"
sudo sh -c "mv  $tmpfs_path/root/rpmbuild/SRPMS/*.rpm $results_path/"

echo '--> Done.'
sudo umount $tmpfs_path/dev
sudo umount $tmpfs_path/proc
sudo umount $tmpfs_path/sys
sudo rm -f /etc/rpm/platform

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
sudo chroot $chroot_path ping -c 1 google.com

# Tests
test_log=$results_path/tests.log
test_root=$tmpfs_path/test-root
test_code=0
rpm -qa --queryformat "%{name}-%{version}-%{release}.%{arch}.%{disttag}%{distepoch}\n" --root $chroot_path >> $results_path/rpm-qa.log
if [ $rc == 0 ] ; then
  ls -la $rpm_path/ >> $test_log
  mkdir $test_root
  rpm -q --queryformat "%{name}-%{version}-%{release}.%{arch}.%{disttag}%{distepoch}\n" urpmi
  sudo urpmi -v --debug --no-verify --no-suggests --test $rpm_path/*.rpm --root $test_root --urpmi-root $chroot_path --auto >> $test_log 2>&1
  test_code=$?
  echo 'Test code output: ' $test_code >> $test_log 2>&1
  rm -rf $test_root
fi

if [ $rc == 0 ] && [ $test_code == 0 ] ; then
  ls -la $src_rpm_path/ >> $test_log
  mkdir $test_root
  sudo urpmi -v --debug --no-verify --test --buildrequires $src_rpm_path/*.rpm --root $test_root --urpmi-root $chroot_path --auto >> $test_log 2>&1
  test_code=$?
  echo 'Test code output: ' $test_code >> $test_log 2>&1
  rm -rf $test_root
fi

if [ $rc != 0 ] || [ $test_code != 0 ] ; then
  tree $chroot_path/builddir/build/ >> $results_path/chroot-tree.log
fi

# Umount tmpfs
cd /
sudo umount $tmpfs_path
sudo rm -rf $tmpfs_path

#move_logs $rpm_path 'rpm'

# Check exit code after build
if [ $rc != 0 ] ; then
  echo '--> Build failed!!!'
  exit 1
fi

# Generate data for container
sudo apt-get install -qq -y rpm
c_data=$results_path/container_data.json
echo '[' > $c_data
for rpm in $results_path/*.rpm $results_path/*.src.rpm ; do
  name=`rpm -qp --queryformat %{NAME} $rpm`
  if [ "$name" != '' ] ; then
    fullname=`basename $rpm`
    version=`rpm -qp --queryformat %{VERSION} $rpm`
    release=`rpm -qp --queryformat %{RELEASE} $rpm`
    sha1=`sha1sum $rpm | awk '{ print $1 }'`

    echo '{' >> $c_data
    echo "\"fullname\":\"$fullname\","  >> $c_data
    echo "\"sha1\":\"$sha1\","          >> $c_data
    echo "\"name\":\"$name\","          >> $c_data
    echo "\"version\":\"$version\","    >> $c_data
    echo "\"release\":\"$release\""     >> $c_data
    echo '},' >> $c_data
  fi
done
# Add '{}'' because ',' before
echo '{}' >> $c_data
echo ']' >> $c_data
ls -l $results_path/

# Move all rpms into results folder
echo "--> mv $rpm_path/*.rpm $results_path/"
mv $rpm_path/*.rpm $results_path/
echo "--> mv $src_rpm_path/*.rpm $results_path/"
mv $src_rpm_path/*.rpm $results_path/

# Remove archives folder
rm -rf $archives_path

# Check exit code after testing
if [ $test_code != 0 ] ; then
  echo '--> Test failed, see: tests.log'
  exit 5
fi
echo '--> Build has been done successfully!'
exit 0
