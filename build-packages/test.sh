#!/bin/sh

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

# 1. Check RPMs
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

# 2. Check SRPMs
if [ $test_code == 0 ] ; then
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

# 3. Fail the tests if we have the same package with newer or same version
if [ $test_code == 0 ] && [ $use_extra_tests == 'true' ] ; then
  echo '--> Checking if same or newer version of the package already exists in repositories' >> $test_log
  sudo mkdir -p $chroot_path/test_root
  sudo cp $rpm_path/*.rpm $chroot_path/

  python $rpm_build_script_path/check_newer_versions.py $chroot_path http://abf-downloads.rosalinux.ru/${platform_name}/repository/${platform_arch}/ >> $test_log 2>&1
  test_code=$?

  echo 'Test code output: ' $test_code >> $test_log 2>&1
  sudo rm -f $chroot_path/*.rpm
  sudo rm -rf $chroot_path/test_root
fi

exit $test_code
