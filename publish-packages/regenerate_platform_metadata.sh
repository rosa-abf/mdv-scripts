#!/bin/sh

# See: https://abf.rosalinux.ru/abf/abf-ideas/issues/91
echo '--> mdv-scripts/publish-packages: regenerate_platform_metadata.sh'

# main,media,contrib,...
repository_names="$REPOSITORY_NAMES"

# /home/vagrant/share_folder contains:
# - http://abf.rosalinux.ru/downloads/rosa2012.1/repository
repository_path=/home/vagrant/share_folder

# Current path:
# - /home/vagrant/scripts/publish-packages
script_path=`pwd`

arches="i586 x86_64"

# A name of special rpm package
data_package="sc-metadata-gen-stage-finish"

# A directory containing generated metadata
metadata_dir="/usr/share/sc-metadata-gen-stages"

# A list of destination files
result_files="applications descriptions alternatives"

# A list of languages
languages="ru"


# distribution's main media_info folder
mkdir -p $repository_path/{i586,x86_64}/media/media_info


for arch in $arches ; do
    # Build repo
    echo "--> [`LANG=en_US.UTF-8  date -u`] Generating additional metadata for Software Center for arch $arch..."

    # Add special repository that contains special packages
    echo "Add the special repository..."
    sudo urpmi.addmedia data_repo "http://abf-downloads.abf.io/sc_personal/repository/$BUILD_FOR_PLATFORM/$arch/main/release/"
  
    # Install special packages
    echo "Install the special package: $data_package..."
    sudo urpmi --auto "$data_package"
  
    # Move result to destination repository
    for f in $result_files; do
        echo "Process result '$f'..."
        cp "$metadata_dir/sc_$f.yml" .
        xz -z -k "sc_$f.yml"
    
        md5sum "sc_$f.yml" > "sc_$f.yml.md5sum"
        md5sum "sc_$f.yml.xz" > "sc_$f.yml.xz.md5sum"
    
        mv -f "sc_$f.yml.xz" "$repository_path/$arch/media/media_info/"
        mv -f "sc_$f.yml.xz.md5sum" "$repository_path/$arch/media/media_info/"
        mv -f "sc_$f.yml.md5sum" "$repository_path/$arch/media/media_info/"
    done
  
    # Move descriptions to destination repository (for each language)
    for l in $languages; do
        echo "Process descriptions for lang '$l'..."
        cp "$metadata_dir/sc_descriptions_$l.yml" .
        xz -z -k "sc_descriptions_$l.yml"
    
        md5sum "sc_descriptions_$l.yml" > "sc_descriptions_$l.yml.md5sum"
        md5sum "sc_descriptions_$l.yml.xz" > "sc_descriptions_$l.yml.xz.md5sum"
    
        mv -f "sc_descriptions_$l.yml.xz" "$repository_path/$arch/media/media_info/"
        mv -f "sc_descriptions_$l.yml.xz.md5sum" "$repository_path/$arch/media/media_info/"
        mv -f "sc_descriptions_$l.yml.md5sum" "$repository_path/$arch/media/media_info/"
    done
  
    # Remove special packages
    echo "Remove the special package: $data_package..."
    sudo urpme --auto "$data_package"
  
    # Remove special repository
    echo "Remove the special repository..."
    sudo urpmi.removemedia data_repo

    echo "--> [`LANG=en_US.UTF-8  date -u`] Done."
done

exit 0