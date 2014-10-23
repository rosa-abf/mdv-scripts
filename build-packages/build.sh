#!/bin/sh

# EXIT CODES:
# 0 - Build complete
# 5 - Tests failed
# 6 - Unpermitted architecture
# other - Build error

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

save_buildroot=${SAVE_BUILDROOT}
use_extra_tests=${USE_EXTRA_TESTS}
rerun_tests=${RERUN_TESTS}
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
  fullname=`sha1=${CACHED_CHROOT_SHA1} /bin/bash ${rpm_build_script_path}/../publish-packages/extract_filename.sh`
  if [ "${fullname}" != '' ] ; then
    comp='gz'
    if [[ "${fullname}" =~ .*\.xz$ ]] ; then
      comp='xz'
    fi

    wget -O ${tmpfs_path}/chroot.tar.${comp} --content-disposition ${file_store_url}/${CACHED_CHROOT_SHA1}
    mkdir -p ${chroot_path}
    sudo tar -C ${tmpfs_path} -xf ${tmpfs_path}/chroot.tar.${comp}
    # Save exit code
    rc=$?
    if [ $rc != 0 ] ; then
      sudo rm -rf ${chroot_path}
      echo "--> Error on extracting chroot with sha1 '$CACHED_CHROOT_SHA1'!!!"
    else
      sudo mv -f ${tmpfs_path}/home/vagrant/tmpfs/* ${tmpfs_path}
      cached_chroot=1
    fi
    sudo rm -rf ${tmpfs_path}/chroot.tar.*z ${tmpfs_path}/home
  else
    echo "--> Chroot with sha1 '${CACHED_CHROOT_SHA1}' does not exist!!!"
  fi
fi
# chroot_path=$chroot_path/root

# We will rerun the build in case when repository is modified in the middle,
# but for safety let's limit number of retest attempts
# (since in case when repository metadata is really broken we can loop here forever)
MAX_RETRIES=5
WAIT_TIME=300
RETRY_GREP_STR="You may need to update your urpmi database\|problem reading synthesis file of medium\|retrieving failed: "

# Build src.rpm
echo '--> Build src.rpm'

build_log_tmp=$src_rpm_path/build.log.tmp
try_retest=true
retry=0
while $try_retest
do
  if [ $cached_chroot == 1 ] ; then
    echo "--> Uses cached chroot with sha1 '$CACHED_CHROOT_SHA1'..."
    mock-urpm --chroot "urpmi.removemedia -a"
    mock-urpm --readdrepo -v --configdir $config_dir
    mock-urpm --buildsrpm --spec $tmpfs_path/SPECS/$spec_name --sources $tmpfs_path/SOURCES/ --resultdir $src_rpm_path --configdir $config_dir -v --no-cleanup-after --no-clean $extra_build_src_rpm_options 2>&1 | tee $build_log_tmp
  else
    mock-urpm --buildsrpm --spec $tmpfs_path/SPECS/$spec_name --sources $tmpfs_path/SOURCES/ --resultdir $src_rpm_path --configdir $config_dir -v --no-cleanup-after $extra_build_src_rpm_options 2>&1 | tee $build_log_tmp
  fi
  # Save exit code
  rc=${PIPESTATUS[0]}
  try_retest=false
  if [[ $rc != 0 && $retry < $MAX_RETRIES ]] ; then
    if grep -q "$RETRY_GREP_STR" $build_log_tmp; then
      echo '--> Repository was changed in the middle, will rerun the build'
      sleep $WAIT_TIME
      sudo urpmi.update -a
      try_retest=true
      (( retry=$retry+1 ))
    fi
  fi
done
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

# Check if a package can be built for the current arch (not forbidden by the spec)
  echo '--> Checking if build for this architecture is allowed by the spec...'
# First, cehck ExcludeArch ...
exclude_arches=`rpm -qp --qf="[%{EXCLUDEARCH}\n]" $src_rpm_name`
if [[ $exclude_arches =~ "$platform_arch" ]]
then
  echo "$platform_arch is specified as ExcludeArch, will not build package for this architecture."
  exit 6
fi

# ... and now, check ExclusiveArch
build_arches=`rpm -qp --qf="[%{EXCLUSIVEARCH}\n]" $src_rpm_name`

if [[ $build_arches != "" ]]
then
  correct_arch=0
  while read build_arch
  do
    if [[ "$build_arch" == "$platform_arch" ]]
    then
      correct_arch=1
      break
    fi
  done << EOT
${build_arches}
EOT
else
  correct_arch=1
fi

if [[ $correct_arch == 0 ]]
then
  echo "The package has ExclusiveArch list, but $platform_arch is not specified in it. Will not build package for this architecture."
  exit 6
fi

echo '--> Building rpm...'

build_log_tmp=$rpm_path/build.log.tmp
try_retest=true
retry=0
while $try_retest
do
  echo "--> mock-urpm $src_rpm_name --resultdir $rpm_path -v --no-cleanup-after --no-clean $extra_build_rpm_options | tee $build_log_tmp"
  mock-urpm $src_rpm_name --resultdir $rpm_path -v --no-cleanup-after --no-clean $extra_build_rpm_options | tee $build_log_tmp
  # Save exit code
  rc=${PIPESTATUS[0]}
  try_retest=false
  if [[ $rc != 0 && $retry < $MAX_RETRIES ]] ; then
    if grep -q "$RETRY_GREP_STR" $build_log_tmp; then
      echo '--> Repository was changed in the middle, will rerun the build'
      sleep $WAIT_TIME
      sudo urpmi.update -a
      try_retest=true
      (( retry=$retry+1 ))
    fi
  fi
done
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

if [[ ${rc} != 0 && ${save_buildroot} == 'true' ]] ; then
  sudo tar --exclude=root/dev -zcvf ${results_path}/rpm-buildroot.tar.gz ${chroot_path}
fi

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
# sudo rm -rf $tmpfs_path

# Extract rpmlint logs into separate file
echo "--> Grepping rpmlint logs from ${rpm_path}/build.log to ${results_path}/rpmlint.log"
sed -n "/Executing \"\/usr\/bin\/rpmlint/,/packages and.*specfiles checked/p" $rpm_path/build.log > $results_path/rpmlint.log

move_logs $rpm_path 'rpm'

# Check exit code after build
if [ $rc != 0 ] ; then
  # Cleanup
  sudo rm -rf $tmpfs_path
  echo '--> Build failed!!!'
  exit 1
fi

# Enable all repositories to get a list of dependent packages
# Note that if we have used extra tests, then these repositories are already enabled (see tests/sh)
if [ $use_extra_tests != 'true' ]; then
  python ${rpm_build_script_path}/enable_all_repos.py ${chroot_path} http://abf-downloads.rosalinux.ru/${platform_name}/repository/${platform_arch}/
fi

# Generate data for container
c_data=${results_path}/container_data.json
project_name=`echo ${git_project_address} | sed s%.*/%% | sed s/.git$//`
echo '[' > ${c_data}
for rpm in ${rpm_path}/*.rpm ${src_rpm_path}/*.src.rpm ; do
  nevr=(`rpm -qp --queryformat "%{NAME} %{EPOCH} %{VERSION} %{RELEASE}" ${rpm}`)
  name=${nevr[0]}
  if [ "${name}" != '' ] ; then
    fullname=`basename $rpm`
    epoch=${nevr[1]}
    version=${nevr[2]}
    release=${nevr[3]}

    dep_list=""
    [[ ! "${fullname}" =~ .*src.rpm$ ]] && dep_list=`sudo chroot ${chroot_path} urpmq --whatrequires ${name} | sort -u | xargs sudo chroot ${chroot_path} urpmq --sourcerpm | cut -d\  -f2 | rev | cut -f3 -d- | rev | sort -u | grep -v "^${project_name}$" | xargs echo`

    sha1=`sha1sum ${rpm} | awk '{ print $1 }'`

    echo "--> dep_list for '${name}':"
    echo ${dep_list}

    echo '{' >> ${c_data}
    echo "\"dependent_packages\":\"${dep_list}\","    >> ${c_data}
    echo "\"fullname\":\"${fullname}\","              >> ${c_data}
    echo "\"sha1\":\"${sha1}\","                      >> ${c_data}
    echo "\"name\":\"${name}\","                      >> ${c_data}
    echo "\"epoch\":\"${epoch}\","                    >> ${c_data}
    echo "\"version\":\"${version}\","                >> ${c_data}
    echo "\"release\":\"${release}\""                 >> ${c_data}
    echo '},' >> ${c_data}
  fi
done
# Add '{}'' because ',' before
echo '{}' >> ${c_data}
echo ']' >> ${c_data}

# Cleanup
sudo rm -rf $tmpfs_path

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
