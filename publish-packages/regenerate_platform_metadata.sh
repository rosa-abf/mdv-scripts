#!/bin/sh

# See: https://abf.rosalinux.ru/abf/abf-ideas/issues/91
echo '--> mdv-scripts/publish-packages: regenerate_platform_metadata.sh'

sudo urpmi --auto perl-YAML-Syck

released="$RELEASED"

# main,media,contrib,...
repository_names="$REPOSITORY_NAMES"

# /home/vagrant/share_folder contains:
# - http://abf.rosalinux.ru/downloads/rosa2012.1/repository
repository_path=/home/vagrant/share_folder

# Current path:
# - /home/vagrant/scripts/publish-packages
script_path=`pwd`

arches="i586 x86_64"

# distribution's main media_info folder
mkdir -p $repository_path/{i586,x86_64}/media/media_info

curl -LO https://abf.rosalinux.ru/abf/SC-metadata-generator/archive/SC-metadata-generator-master.tar.gz
tar -xzf SC-metadata-generator-master.tar.gz
rm -f SC-metadata-generator-master.tar.gz

project_path=$script_path/SC-metadata-generator-master
cd $project_path

for arch in $arches ; do
  # Build repo
  echo "--> [`LANG=en_US.UTF-8  date -u`] Generating additional metadata for Software Center..."
  paths=''
  for name in ${repository_names//,/ } ; do
    paths+="$repository_path/$arch/$name/release/media_info "
    if [ "$released" == 'true' ] ; then
      paths+="$repository_path/$arch/$name/updates/media_info "
    fi
  done

  # Downloads extra files by .abf.yml
  # dump_gui_apps removes files after each run
  sudo ruby $script_path/../abf_yml.rb -p $project_path

  echo "perl dump_gui_apps $paths"
  perl dump_gui_apps $paths
  # Save exit code
  rc=$?
  if [ $rc != 0 ] ; then
    exit $rc
  fi

  mv -f gui_pkgs.yml.xz $repository_path/$arch/media/media_info/
  mv -f sc_alternatives.yml.xz $repository_path/$arch/media/media_info/

  echo "--> [`LANG=en_US.UTF-8  date -u`] Done."
done

exit 0