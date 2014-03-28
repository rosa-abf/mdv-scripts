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
sudo rm -rf $archives_path $results_path $tmpfs_path $project_path
mkdir  $archives_path $results_path $tmpfs_path $project_path

# Mount tmpfs
# sudo mount -t tmpfs tmpfs -o size=40000M,nr_inodes=10M $tmpfs_path

# Download project
# Fix for: 'fatal: index-pack failed'
git config --global core.compression -1
git clone $git_project_address $project_path
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

if [[ "$platform_name" == "cooker" && ("$platform_arch" == "armv7l" || "$platform_arch" == "armv7hl" )]]; then
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

if [[ "$platform_name" == "cooker" && ("$platform_arch" == "aarch64" )]]; then
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

# create SPECS folder and move *.spec
mkdir $tmpfs_path/SPECS
mv $project_path/*.spec $tmpfs_path/SPECS/

#create SOURCES folder and move src
mkdir $tmpfs_path/SOURCES

# account for hidden files
for x in $project_path/* $project_path/.[!.]* $project_path/..?*; do
  if [ -e "$x" ]; then
    mv -- "$x" $tmpfs_path/SOURCES/
  fi
done

# remove unnecessary files
rm -f $tmpfs_path/SOURCES/.abf.yml $tmpfs_path/SOURCES/.gitignore

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

# Build src.rpm
echo '--> Build src.rpm'
mock-urpm --buildsrpm --spec $tmpfs_path/SPECS/$spec_name --sources $tmpfs_path/SOURCES/ --resultdir $src_rpm_path --configdir $config_dir -v --no-cleanup-after $extra_build_src_rpm_options
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

r=`head -1 $config_dir/default.cfg |
  sed -e "s/config_opts//g" |
  sed -e "s/\[//g" |
  sed -e "s/\]//g" |
  sed -e "s/root//g" |
  sed -e "s/=//g" |
  sed -e "s/'//g"|
  sed -e "s/ //g"`
chroot_path=$tmpfs_path/$r/root
echo "Debug Message"
echo $chroot_path
ls -la $chroot_path
echo "Debug Message"
echo '--> Checking internet connection...'
sudo chroot $chroot_path ping -c 1 google.com

# Tests

# We will rerun the tests in case when repository is modified in the middle,
# but for safety let's limit number of retest attempts
# (since in case when repository metadata is really broken we can loop here forever)
MAX_RETRIES=5
WAIT_TIME=300
RETRY_GREP_STR="You may need to update your urpmi database\|problem reading synthesis file of medium\|retrieving failed: "

test_log=$results_path/tests.log
test_log_tmp=$results_path/tests.log.tmp
test_root=$tmpfs_path/test-root
test_code=0
rpm -qa --queryformat "%{name}-%{version}-%{release}.%{arch}.%{disttag}%{distepoch}\n" --root $chroot_path >> $results_path/rpm-qa.log
if [ $rc == 0 ] ; then
  ls -la $rpm_path/ >> $test_log
  sudo mkdir -p $chroot_path/test_root
  rpm -q --queryformat "%{name}-%{version}-%{release}.%{arch}.%{disttag}%{distepoch}\n" urpmi
  sudo cp $rpm_path/*.rpm $chroot_path/

  try_retest=true
  retry=0
  while $try_retest
  do
#    sudo urpmi --downloader wget --wget-options --auth-no-challenge -v --debug --no-verify --no-suggests --test $rpm_path/*.rpm --root $test_root --urpmi-root $chroot_path --auto > $test_log_tmp 2>&1
    sudo chroot $chroot_path urpmi --downloader wget --wget-options --auth-no-challenge -v --debug --no-verify --no-suggests --test `ls  $chroot_path |grep rpm` --root test_root --auto > $test_log_tmp 2>&1
    test_code=$?
    try_retest=false
    if [[ $test_code != 0 && $retry < $MAX_RETRIES ]] ; then
      if grep -q "$RETRY_GREP_STR" $test_log_tmp; then
        echo '--> Repository was changed in the middle, will rerun the tests' >> $test_log
        sleep $WAIT_TIME
        sudo chroot $chroot_path urpmi.update -a >> $test_log 2>&1
        try_retest=true
        (( retry=$retry+1 ))
      fi
    fi
  done

  cat $test_log_tmp >> $test_log
  echo 'Test code output: ' $test_code >> $test_log 2>&1
  sudo rm -f  $chroot_path/*.rpm
  sudo rm -rf $chroot_path/test_root
  rm -f $test_log_tmp
fi

if [ $rc == 0 ] && [ $test_code == 0 ] ; then
  ls -la $src_rpm_path/ >> $test_log
  sudo mkdir -p $chroot_path/test_root
  sudo cp $src_rpm_path/*.rpm $chroot_path/

  try_retest=true
  retry=0
  while $try_retest
  do
#   sudo urpmi --downloader wget --wget-options --auth-no-challenge -v --debug --no-verify --test --buildrequires $src_rpm_path/*.rpm --root $test_root --urpmi-root $chroot_path --auto > $test_log_tmp 2>&1
    sudo chroot $chroot_path urpmi --downloader wget --wget-options --auth-no-challenge -v --debug --no-verify --test --buildrequires `ls  $chroot_path |grep src.rpm` --root test_root --auto > $test_log_tmp 2>&1
    test_code=$?
    try_retest=false
    if [[ $test_code != 0 && $retry < $MAX_RETRIES ]] ; then
      if grep -q "$RETRY_GREP_STR" $test_log_tmp; then
        echo '--> Repository was changed in the middle, will rerun the tests' >> $test_log
        sleep $WAIT_TIME
        sudo chroot $chroot_path urpmi.update -a >> $test_log 2>&1
        try_retest=true
        (( retry=$retry+1 ))
      fi
    fi
  done

  cat $test_log_tmp >> $test_log
  echo 'Test code output: ' $test_code >> $test_log 2>&1
  sudo rm -f $chroot_path/*.rpm
  sudo rm -rf $chroot_path/test_root
  rm -f $test_log_tmp
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
