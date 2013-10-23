#!/bin/sh

echo '--> mdv-scripts/build-packages: init_cfg_config.sh'

extra_cfg_options="$EXTRA_CFG_OPTIONS"
uname="$UNAME"
email="$EMAIL"
rpm_build_script_path="$RPM_BUILD_SCRIPT_PATH"
config_dir="$CONFIG_DIR"
config_name="$CONFIG_NAME"
platform_arch="$PLATFORM_ARCH"
platform_name="$PLATFORM_NAME"

media_list=/home/vagrant/container/media.list

# TODO: Remove later, added temporally
if [ "$platform_name" == 'rosa-dx-chrome-1.0' ] ; then
cat <<EOF>> $media_list
rosa2012lts_main_release http://abf-downloads.rosalinux.ru/rosa2012lts/repository/$platform_arch/main/release
rosa2012lts_contrib_release http://abf-downloads.rosalinux.ru/rosa2012lts/repository/$platform_arch/contrib/release
rosa2012lts_contrib_updates http://abf-downloads.rosalinux.ru/rosa2012lts/repository/$platform_arch/contrib/updates
dx_rc_main http://abf-downloads.rosalinux.ru/dx_rc_personal/repository/rosa-dx-chrome-1.0/$platform_arch/main/release/
EOF
fi
if [ "$platform_name" == "red3" ]; then
cat <<EOF>> $media_list
rosa2012.1_contrib_release http://abf-downloads.rosalinux.ru/rosa2012.1/repository/$platform_arch/contrib/release
rosa2012.1_contrib_updates http://abf-downloads.rosalinux.ru/rosa2012.1/repository/$platform_arch/contrib/updates
EOF
fi

default_cfg=$rpm_build_script_path/configs/default.cfg

EXTRA_CFG_OPTIONS="$extra_cfg_options" \
  UNAME=$uname \
  EMAIL=$email \
  DEFAULT_CFG=$default_cfg \
  PLATFORM_ARCH=$platform_arch \
  /bin/bash "$rpm_build_script_path/configs/$config_name.sh"


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