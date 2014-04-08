#!/bin/sh

echo '--> mdv-scripts/cached-chroot: build.sh'


platform_name="$PLATFORM_NAME"
token="$TOKEN"
arches=${ARCHES:-"i586 x86_64"}

rpm_build_script_path=`pwd`
rpm_build_script_path="${rpm_build_script_path}/../build-packages"

results_path="/home/vagrant/results"
tmpfs_path="/home/vagrant/tmpfs"

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

for arch in $arches ; do

  # Init media list
  media_list=/home/vagrant/container/media.list
  prefix=''
  if [ "${token}" == '' ] ; then
    prefix="${token}:@"
  fi
  base_url = "http://${prefix}abf-downloads.rosalinux.ru/${platform_name}/repository/${arch}/main"

  echo "${platform_name}_release ${base_url}/release/" > $media_list

  code=`curl --write-out %{http_code} --silent --output /dev/null ${base_url}/updates/`
  if [ "${code}" == '200' ] ; then
    echo "${platform_name}_updates ${base_url}/updates/" >> $media_list
  fi

  # Init config file
  # EXTRA_CFG_OPTIONS="$extra_cfg_options" \
  #   EXTRA_CFG_URPM_OPTIONS="$extra_cfg_urpm_options" \
    # UNAME=$uname \
    # EMAIL=$email \
    # RPM_BUILD_SCRIPT_PATH=$rpm_build_script_path \
  CONFIG_DIR=$config_dir \
    CONFIG_NAME=$config_name \
    PLATFORM_ARCH=$arch \
    PLATFORM_NAME=$platform_name \
    /bin/bash $rpm_build_script_path/init_cfg_config.sh

  # Build chroot
  echo "--> Build chroot for ${platform_name}-${arch}"
  mock-urpm --configdir $config_dir -v --no-cleanup-after
  # Save exit code
  rc=$?
  echo '--> Done.'

  # Check exit code after build
  if [ $rc != 0 ] ; then
    echo '--> Build failed: mock-urpm encountered a problem.'
    exit 1
  fi

  chroot=`ls -1 ${tmpfs_path} | grep ${arch} | head -1`

  if [ "${chroot}" == '' ] ; then
    echo '--> Build failed: chroot does not exist.'
    exit 1
  fi

  tar -zcvf ${results_path}/${chroot}.tar.gz ${tmpfs_path}/${chroot}
  rm -rf ${tmpfs_path}/${chroot}
done

echo '--> Build has been done successfully!'
exit 0

