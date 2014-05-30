#!/bin/sh

echo "Checking /etc/rpm/platform"
cat /etc/rpm/platform
echo "Removing /etc/rpm/platform to avoid problems"
sudo rm -rf /etc/rpm/platform

# sudo urpmi.update -a
# for p in wget curl urpmi mock-urpm perl-URPM genhdlist2 tree ; do
# sudo urpmi --auto $p
# done

echo '--> mdv-scripts/build-packages: build.sh'

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
extra_cfg_urpm_options="$EXTRA_CFG_URPM_OPTIONS"
extra_build_src_rpm_options="$EXTRA_BUILD_SRC_RPM_OPTIONS"
extra_build_rpm_options="$EXTRA_BUILD_RPM_OPTIONS"

use_extra_tests=$USE_EXTRA_TESTS
rerun_tests=$RERUN_TESTS
# list of packages for tests relaunch
packages="$PACKAGES"

echo $git_project_address | awk '{ gsub(/\:\/\/.*\:\@/, "://[FILTERED]@"); print }'
echo $commit_hash
echo $uname
echo $email

archives_path="/home/vagrant/archives"
results_path="/home/vagrant/results"
tmpfs_path="/home/vagrant/tmpfs"
project_path="$tmpfs_path/project"
rpm_build_script_path=`pwd`

sudo chown vagrant:vagrant -R /home/vagrant

# !!!!!
/bin/bash $rpm_build_script_path/../startup-vm/startup.sh

# sudo umount -l $tmpfs_path
sudo rm -rf $archives_path $results_path $tmpfs_path
mkdir  $archives_path $results_path $tmpfs_path

# Mount tmpfs
# sudo mount -t tmpfs tmpfs -o size=40000M,nr_inodes=10M $tmpfs_path

if [[ "$rerun_tests" != 'true' || "$platform_arch" == "armv7l" || "$platform_arch" == "armv7hl" || "$platform_arch" == "aarch64" ]] ; then
  # Download project
  # Fix for: 'fatal: index-pack failed'
  git config --global core.compression -1

  # We will rerun the git clone in case when something wrong,
  # but for safety let's limit number of retest attempts
  MAX_RETRIES=5
  WAIT_TIME=10
  try_reclone=true
  retry=0
  while $try_reclone
  do
    sudo rm -rf $project_path
    mkdir $project_path
    git clone $git_project_address $project_path
    rc=$?
    try_reclone=false
    if [[ $rc != 0 && $retry < $MAX_RETRIES ]] ; then
      try_reclone=true
      (( retry=$retry+1 ))
      echo "--> Something wrong with git repository, next try (${retry} from ${MAX_RETRIES})..."
      echo "--> Delay ${WAIT_TIME} sec..."
      sleep $WAIT_TIME
    fi
  done

  cd $project_path
  git submodule update --init
  git remote rm origin
  git checkout $commit_hash

  # Downloads extra files by .abf.yml
  ruby $rpm_build_script_path/../abf_yml.rb -p $project_path

  # Check count of *.spec files (should be one)
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

  # build changelog (limited to ~10 for reasonable changelog size)
  sed -i '/%changelog/,$d' $spec_name
  echo >> $spec_name
  echo '%changelog' >> $spec_name
  changelog_log=$results_path/changelog.log
  echo "python $rpm_build_script_path/build-changelog.py -b 5 -e $commit_hash -n $spec_name >> $changelog_log"
  python $rpm_build_script_path/build-changelog.py -b 5 -e $commit_hash -n $spec_name >> $changelog_log
  echo "cat $changelog_log >> $spec_name"
  cat $changelog_log >> $spec_name

  # Remove .git folder
  rm -rf $project_path/.git
fi

if [[ "$platform_arch" == "armv7l" || "$platform_arch" == "armv7hl" ]]; then
  cd $rpm_build_script_path
  UNAME="$UNAME" \
    EXTRA_CFG_OPTIONS="$extra_cfg_options" \
    EXTRA_CFG_URPM_OPTIONS="$extra_cfg_urpm_options" \
    EXTRA_BUILD_SRC_RPM_OPTIONS="$extra_build_src_rpm_options" \
    EXTRA_BUILD_RPM_OPTIONS="$extra_build_rpm_options" \
    EMAIL="$EMAIL" \
    PLATFORM_NAME="$PLATFORM_NAME" \
    PLATFORM_ARCH="$ARCH" \
    /bin/bash $rpm_build_script_path/cooker/openmandriva-arm.sh
  # Save exit code
  rc=$?
  exit $rc
fi

if [[ "$platform_arch" == "aarch64" ]]; then
  cd $rpm_build_script_path
  UNAME="$UNAME" \
    EXTRA_CFG_OPTIONS="$extra_cfg_options" \
    EXTRA_CFG_URPM_OPTIONS="$extra_cfg_urpm_options" \
    EXTRA_BUILD_SRC_RPM_OPTIONS="$extra_build_src_rpm_options" \
    EXTRA_BUILD_RPM_OPTIONS="$extra_build_rpm_options" \
    EMAIL="$EMAIL" \
    PLATFORM_NAME="$PLATFORM_NAME" \
    PLATFORM_ARCH="$ARCH" \
    /bin/bash $rpm_build_script_path/cooker/openmandriva-arm64.sh
  # Save exit code
  rc=$?
  exit $rc
fi

mkdir $tmpfs_path/SPECS
mkdir $tmpfs_path/SOURCES

if [ "$rerun_tests" != 'true' ] ; then
  # create SPECS folder and move *.spec
  mv $project_path/*.spec $tmpfs_path/SPECS/

  #create SOURCES folder and move src

  # account for hidden files
  for x in $project_path/* $project_path/.[!.]* $project_path/..?*; do
    if [ -e "$x" ]; then
      mv -- "$x" $tmpfs_path/SOURCES/
    fi
  done

  # remove unnecessary files
  rm -f $tmpfs_path/SOURCES/.abf.yml $tmpfs_path/SOURCES/.gitignore
fi

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


config_name="mdv"
if [[ "$platform_name" =~ .*lts$ ]] ; then
  config_name="mdv-lts"
elif [[ "$platform_name" =~ ^(cooker|openmandriva) ]] ; then
  config_name="openmandriva"
fi

# Init config file
EXTRA_CFG_OPTIONS="$extra_cfg_options" \
  EXTRA_CFG_URPM_OPTIONS="$extra_cfg_urpm_options" \
  UNAME=$uname \
  EMAIL=$email \
  RPM_BUILD_SCRIPT_PATH=$rpm_build_script_path \
  CONFIG_DIR=$config_dir \
  CONFIG_NAME=$config_name \
  PLATFORM_ARCH=$platform_arch \
  PLATFORM_NAME=$platform_name \
  /bin/bash $rpm_build_script_path/init_cfg_config.sh

r=`cat $config_dir/default.cfg | grep "config_opts\['root']" | awk '{ print $3 }' | sed "s/'//g"`
chroot_path=$tmpfs_path/$r

# Rerun tests
if [ "$rerun_tests" == 'true' ] ; then
  export RERUN_TESTS='true' \
       PACKAGES=${packages} \
       results_path=$results_path \
       tmpfs_path=$tmpfs_path \
       rpm_path=$rpm_path \
       chroot_path=$chroot_path \
       src_rpm_path=$src_rpm_path \
       rpm_build_script_path=$rpm_build_script_path \
       use_extra_tests=$use_extra_tests \
       platform_name=$platform_name \
       platform_arch=$platform_arch

  /bin/bash $rpm_build_script_path/tests.sh
  # Save exit code
  rc=$?
  if [ ${rc} != 0 ] ; then
    echo '--> Test failed, see: tests.log'
    exit 5
  fi
  exit 0
fi

# Download tarball with existing chroot, if any
# The tarball should contain 'root' folder which will be unpacked
# to the directory used by mock-urpm

cached_chroot=0
if [[ "${CACHED_CHROOT_SHA1}" != '' ]] ; then
  file_store_url='http://file-store.rosalinux.ru/api/v1/file_stores'
  if [ `curl ${file_store_url}.json?hash=${CACHED_CHROOT_SHA1}` == '[]' ] ; then
    echo "--> Chroot with sha1 '$CACHED_CHROOT_SHA1' does not exist!!!"
  else
    wget -O ${tmpfs_path}/chroot.tar.gz --content-disposition ${file_store_url}/${CACHED_CHROOT_SHA1}
    mkdir -p ${chroot_path}
    sudo tar -C ${tmpfs_path} -xzf ${tmpfs_path}/chroot.tar.gz
    # Save exit code
    rc=$?
    if [ $rc != 0 ] ; then
      sudo rm -rf ${chroot_path}
      echo "--> Error on extracting chroot with sha1 '$CACHED_CHROOT_SHA1'!!!"
    else
      sudo mv -f ${tmpfs_path}/home/vagrant/tmpfs/* ${tmpfs_path}
      cached_chroot=1
    fi
    sudo rm -rf ${tmpfs_path}/chroot.tar.gz ${tmpfs_path}/home
  fi
fi
# chroot_path=$chroot_path/root

# Build src.rpm
echo '--> Build src.rpm'
if [ $cached_chroot == 1 ] ; then
  echo "--> Uses cached chroot with sha1 '$CACHED_CHROOT_SHA1'..."
  mock-urpm --chroot "urpmi.removemedia -a"
  mock-urpm --readdrepo -v --configdir $config_dir
  mock-urpm --buildsrpm --spec $tmpfs_path/SPECS/$spec_name --sources $tmpfs_path/SOURCES/ --resultdir $src_rpm_path --configdir $config_dir -v --no-cleanup-after --no-clean $extra_build_src_rpm_options
else
  mock-urpm --buildsrpm --spec $tmpfs_path/SPECS/$spec_name --sources $tmpfs_path/SOURCES/ --resultdir $src_rpm_path --configdir $config_dir -v --no-cleanup-after $extra_build_src_rpm_options
fi
# Save exit code
rc=$?
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

r=`cat $config_dir/default.cfg | grep "config_opts\['root']" | awk '{ print $3 }' | sed "s/'//g"`
chroot_path=$tmpfs_path/$r/root
echo "Debug Message"
echo $chroot_path
ls -la $chroot_path
echo "Debug Message"
echo '--> Checking internet connection...'
sudo chroot $chroot_path ping -c 1 google.com

rpm -qa --queryformat "%{name}-%{version}-%{release}.%{arch}.%{disttag}%{distepoch}\n" --root $chroot_path >> $results_path/rpm-qa.log

# Tests
test_code=0
if [ $rc == 0 ]
then
  export RERUN_TESTS='false' \
       results_path=$results_path \
       tmpfs_path=$tmpfs_path \
       rpm_path=$rpm_path \
       chroot_path=$chroot_path \
       src_rpm_path=$src_rpm_path \
       rpm_build_script_path=$rpm_build_script_path \
       use_extra_tests=$use_extra_tests \
       platform_name=$platform_name \
       platform_arch=$platform_arch

  /bin/bash $rpm_build_script_path/tests.sh
  test_code=$?
fi

if [ $rc != 0 ] || [ $test_code != 0 ] ; then
  tree $chroot_path/builddir/build/ >> $results_path/chroot-tree.log
fi

# Umount tmpfs
cd /
# sudo umount -l $tmpfs_path
sudo rm -rf $tmpfs_path

# Extract rpmlint logs into separate file
echo "--> Grepping rpmlint logs from ${rpm_path}/build.log to ${results_path}/rpmlint.log"
sed -n "/Executing \"\/usr\/bin\/rpmlint/,/packages and.*specfiles checked/p" $rpm_path/build.log > $results_path/rpmlint.log

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

# Check exit code after testing
if [ $test_code != 0 ] ; then
  echo '--> Test failed, see: tests.log'
  exit 5
fi
echo '--> Build has been done successfully!'
exit 0
