#!/bin/sh

echo '--> mdv-scripts/build-packages/configs: openmandriva.sh'

extra_cfg_options="$EXTRA_CFG_OPTIONS"
extra_cfg_urpm_options="$EXTRA_CFG_URPM_OPTIONS"
uname="$UNAME"
email="$EMAIL"
platform_arch="$PLATFORM_ARCH"
default_cfg="$DEFAULT_CFG"

cat <<EOF> $default_cfg
config_opts['root'] = 'openmandriva-2013.0-$platform_arch'
config_opts['target_arch'] = '$platform_arch --without check'
config_opts['legal_host_arches'] = ('i586', 'i686', 'x86_64', 'armv7l', 'armv7hl')

config_opts['chroot_setup'] = 'basesystem-minimal locales locales-en locales-de locales-uk locales-es locales-ru distro-release-OpenMandriva gnupg rpm-build urpmi meta-task wget'
config_opts['urpmi_options'] = '--no-suggests --no-verify-rpm --fastunsafe --ignoresize --ignorearch --excludedocs $extra_cfg_options'
config_opts['urpm_options'] = '--wget --wget-options --auth-no-challenge $extra_cfg_urpm_options'

# If it's True - current urpmi configs will be copied to the chroot.
# Ater that other media will be added.
# config_opts['use_system_media'] = True

config_opts['plugin_conf']['root_cache_enable'] = False
config_opts['plugin_conf']['ccache_enable'] = False
config_opts['use_system_media'] = False
config_opts['basedir'] = '/home/vagrant/tmpfs'
config_opts['cache_topdir'] = '/home/vagrant/tmpfs/cache'

config_opts['dist'] = 'cooker'  # only useful for --resultdir variable subst
config_opts['macros']['%packager'] = '$uname <$email>'

config_opts["urpmi_media"] = {
EOF

