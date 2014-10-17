#!/bin/sh

echo '--> mdv-scripts/cached-chroot: build.sh'


platform_name="$PLATFORM_NAME"
token="$TOKEN"
arches=${ARCHES:-"i586 x86_64"}

rpm_build_script_path="/home/vagrant/iso_builder/build-packages"
results_path="/home/vagrant/results"
tmpfs_path="/home/vagrant/tmpfs"
container_path="/home/vagrant/container"

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

function copy_qemu {
(while [ ! -e  $tmpfs_path/openmandriva-$arch/root/usr/bin/ ]
  do sleep 1;done
  sudo cp -v $rpm_build_script_path/qemu*  $tmpfs_path/openmandriva-$arch/root/usr/bin/) &
  subshellpid=$!
}

mkdir -p ${container_path}
for arch in $arches ; do

  # Init media list
  media_list=${container_path}/media.list
  prefix=''
  if [ "${token}" != '' ] ; then
    prefix="${token}:@"
  fi
  base_url="http://${prefix}abf-downloads.rosalinux.ru/${platform_name}/repository/${arch}/main"

  echo "${platform_name}_release ${base_url}/release/" > $media_list

  updates_url="${base_url}/updates/"
  if [ `curl --write-out %{http_code} --silent --output /dev/null ${updates_url}` == '200' ] ; then
    echo "${platform_name}_updates ${updates_url}" >> $media_list
  fi

  # Init config file
  # EXTRA_CFG_OPTIONS="$extra_cfg_options" \
  #   EXTRA_CFG_URPM_OPTIONS="$extra_cfg_urpm_options" \
    # UNAME=$uname \
    # EMAIL=$email \
  RPM_BUILD_SCRIPT_PATH=$rpm_build_script_path \
    CONFIG_DIR=$config_dir \
    CONFIG_NAME=$config_name \
    PLATFORM_ARCH=$arch \
    PLATFORM_NAME=$platform_name \
    /bin/bash $rpm_build_script_path/init_cfg_config.sh

  # Build chroot
  echo "--> Build chroot for ${platform_name}-${arch}"
  if [ ! -L /etc/localtime ]; then
	  echo "no symlink to timezone"
  # Try to fix: [Errno 2] No such file or directory: '/etc/localtime'
          sudo ln -s /usr/share/zoneinfo/UTC /etc/localtime
  else
	  echo "timezone already installed"
  fi

  sudo urpmi.update -a
  PACKAGES=(wget curl urpmi perl-Locale-gettext perl-URPM mock-urpm genhdlist2 tree git rpm ruby python-rpm5utils python-rpm urpm-tools)
  sudo urpmi ${PACKAGES[*]} --downloader wget --wget-options --auth-no-challenge --auto --no-suggests --no-verify-rpm --ignorearch
  
  if [[ "$arch" == "aarch64" || "$arch" == "armv7hl" ]]; then
	sudo sh -c "echo '$arch-mandriva-linux-gnueabi' > /etc/rpm/platform"
	sudo sh -c "echo ':aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7:\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff:/usr/bin/qemu-aarch64-binfmt:P' > /proc/sys/fs/binfmt_misc/register"
	sudo sh -c "echo ':arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm-binfmt:P' > /proc/sys/fs/binfmt_misc/register"
	wget -O $rpm_build_script_path/qemu-arm --content-disposition http://file-store.rosalinux.ru/api/v1/file_stores/aacd76a9dd55589ccabd8164c2d6b4f1895065e2 --no-check-certificate &> /dev/null
	wget -O $rpm_build_script_path/qemu-arm-binfmt --content-disposition http://file-store.rosalinux.ru/api/v1/file_stores/56a418f0dee40be3be0be89350a8c6eff2c685e0 --no-check-certificate &> /dev/null
	wget -O $rpm_build_script_path/qemu-aarch64 --content-disposition http://file-store.rosalinux.ru/api/v1/file_stores/d4b225da9e8bc964a4b619109a60a9fe4d0a7b87 --no-check-certificate &> /dev/null
	wget -O $rpm_build_script_path/qemu-aarch64-binfmt --content-disposition http://file-store.rosalinux.ru/api/v1/file_stores/8f5abb1c8a8a9163c258611858d2a109536c1a56 --no-check-certificate &> /dev/null
	chmod +x $rpm_build_script_path/qemu-*
	copy_qemu
  fi

  mock-urpm --init --configdir $config_dir -v --no-cleanup-after
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

  tar --exclude=root/dev -zcvf ${results_path}/${chroot}.tar.gz ${tmpfs_path}/${chroot}
  rm -rf ${tmpfs_path}/${chroot}
done

echo '--> Build has been done successfully!'
exit 0

