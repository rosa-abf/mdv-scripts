#!/bin/sh

echo '--> mdv-scripts/build-packages/configs: mdv-lts.sh'

extra_cfg_options="$EXTRA_CFG_OPTIONS"
uname="$UNAME"
email="$EMAIL"
platform_arch="$PLATFORM_ARCH"
default_cfg="$DEFAULT_CFG"

cat <<EOF> $default_cfg
config_opts['root'] = 'Rosa-2012lts-$platform_arch'
config_opts['target_arch'] = '$platform_arch'
config_opts['legal_host_arches'] = ('i586', 'i686', 'x86_64')
EOF

if [ "$platform_arch" == 'x86_64' ] ; then
cat <<EOF>> $default_cfg
config_opts['chroot_setup'] = 'basesystem-minimal locales locales-en locales-de locales-uk locales-es locales-ru basesystem-minimal lib64mpc2 lib64mpfr4 lib64natspec0 lib64pwl5 make patch unzip mandriva-release-common binutils curl gcc gcc-c++ gnupg mandriva-release-Free rpm-build wget'
EOF
else
cat <<EOF>> $default_cfg
config_opts['chroot_setup'] = 'basesystem-minimal locales locales-en locales-de locales-uk locales-es locales-ru basesystem-minimal libmpc2 libmpfr4 libnatspec0 libpwl5 make patch unzip mandriva-release-common binutils curl gcc gcc-c++ gnupg mandriva-release-Free rpm-build wget'
EOF
fi

cat <<EOF>> $default_cfg
config_opts['urpmi_options'] = '--no-suggests --no-verify-rpm --fastunsafe --ignoresize $extra_cfg_options'
config_opts['urpm_options'] = '--wget --wget-options --auth-no-challenge'

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

