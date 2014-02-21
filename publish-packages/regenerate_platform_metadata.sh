#!/bin/sh

# See: https://abf.rosalinux.ru/abf/abf-ideas/issues/91
echo '--> mdv-scripts/publish-packages: regenerate_platform_metadata.sh'

sudo urpmi --auto python

# main,media,contrib,...
repository_names="$REPOSITORY_NAMES"

# /home/vagrant/share_folder contains:
# - http://abf.rosalinux.ru/downloads/rosa2012.1/repository
repository_path=/home/vagrant/share_folder

# Current path:
# - /home/vagrant/scripts/publish-packages
script_path=`pwd`

arches="i586 x86_64"

# Prefix for all special packages
data_packages_prefix="sc-metadata-gen-stages"

# A list of all required packages containing data prepared for SC
data_packages="packages alternatives wiki-descriptions"

# A list of generated files
result_files="applications descriptions alternatives"

# A list of languages
languages="ru"


# distribution's main media_info folder
mkdir -p $repository_path/{i586,x86_64}/media/media_info

curl -LO https://abf.rosalinux.ru/abf/SC-metadata-generator/archive/SC-metadata-generator-master.tar.gz
tar -xzf SC-metadata-generator-master.tar.gz
rm -f SC-metadata-generator-master.tar.gz

project_path=$script_path/SC-metadata-generator-master
cd $project_path

# Download script and extra files by .abf.yml
sudo ruby $script_path/../abf_yml.rb -p $project_path

for arch in $arches ; do
  # Build repo
  echo "--> [`LANG=en_US.UTF-8  date -u`] Generating additional metadata for Software Center for arch $arch..."

  # Add special repository that contains special packages
  echo "Add the special repository..."
  sudo urpmi.addmedia data_repo "http://abf-downloads.abf.io/sc_personal/repository/rosa2012.1/$arch/main/release/"
  
  # Install special packages
  for pkg in $data_packages; do
    echo "Install the special package: $data_packages_prefix-$pkg..."
    sudo urpmi --auto "$data_packages_prefix-$pkg"
  done

  # Construct argument for script
  param=`echo $languages | tr " " ","`
  
  # Generate metadata
  echo "Generate SC Metadata..."
  python generate_metadata.py "$param"
  # Save exit code
  rc=$?
  if [ $rc != 0 ] ; then
    exit $rc
  fi
  
  # Remove special packages
  for pkg in $data_packages; do
    echo "Remove the special package: $data_packages_prefix-$pkg..."
    sudo urpme --auto "$data_packages_prefix-$pkg"
  done
  
  # Remove special repository
  echo "Remove the special repository..."
  sudo urpmi.removemedia data_repo
  
  # Move result to destination repository
  for f in $result_files; do
    echo "Move result $f to the destination repository..."
    mv -f "sc_$f.yml.xz" "$repository_path/$arch/media/media_info/"
    mv -f "sc_$f.yml.xz.md5sum" "$repository_path/$arch/media/media_info/"
    mv -f "sc_$f.yml.md5sum" "$repository_path/$arch/media/media_info/"
  done
  
  # Move descriptions to destination repository (for each language)
  for l in $languages; do
    echo "Move descriptions for lang $l to the destination repository..."
    mv -f "sc_descriptions_$l.yml.xz" "$repository_path/$arch/media/media_info/"
    mv -f "sc_descriptions_$l.yml.xz.md5sum" "$repository_path/$arch/media/media_info/"
    mv -f "sc_descriptions_$l.yml.md5sum" "$repository_path/$arch/media/media_info/"
  done

  echo "--> [`LANG=en_US.UTF-8  date -u`] Done."
done

exit 0