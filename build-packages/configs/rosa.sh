#!/bin/sh

echo '--> mdv-scripts/build-packages/configs: rosa.sh'

extra_cfg_options="$EXTRA_CFG_OPTIONS"
extra_cfg_urpm_options="$EXTRA_CFG_URPM_OPTIONS"
uname="$UNAME"
email="$EMAIL"
platform_arch="$PLATFORM_ARCH"
default_cfg="$DEFAULT_CFG"
platform_name="$PLATFORM_NAME"

cat <<EOF> $default_cfg
config_opts['root'] = 'Rosa-$platform_arch'
config_opts['target_arch'] = '$platform_arch'
config_opts['legal_host_arches'] = ('i586', 'i686', 'x86_64')
EOF

cat <<EOF>> $default_cfg
config_opts['chroot_setup'] = 'basesystem-build branding-configs-$platform_name'
EOF

cat <<EOF>> $default_cfg
config_opts['urpmi_options'] = '--downloader wget --wget-options --auth-no-challenge --retry 5 --no-suggests --no-verify-rpm --fastunsafe --ignoresize $extra_cfg_options'
config_opts['urpm_options'] = '--xml-info=never --downloader wget --wget-options --auth-no-challenge $extra_cfg_urpm_options'

# If it's True - current urpmi configs will be copied to the chroot.
# Ater that other media will be added.
# config_opts['use_system_media'] = True

config_opts['plugin_conf']['root_cache_enable'] = False
config_opts['plugin_conf']['ccache_enable'] = False
config_opts['use_system_media'] = False
config_opts['basedir'] = '/home/vagrant/tmpfs'
config_opts['cache_topdir'] = '/home/vagrant/tmpfs/cache'

config_opts['dist'] = 'rosa2012lts'  # only useful for --resultdir variable subst
config_opts['macros']['%packager'] = '$uname <$email>'

config_opts["urpmi_media"] = {
EOF

