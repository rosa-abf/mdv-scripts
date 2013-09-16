#!/bin/sh

echo '--> mdv-scripts/publish-packages: build.sh'

# Update genhdlist2
sudo urpmi.update -a
sudo urpmi --auto genhdlist2

released="$RELEASED"
rep_name="$REPOSITORY_NAME"
is_container="$IS_CONTAINER"
id="$ID"
# save_to_platform - main or personal platform
save_to_platform="$SAVE_TO_PLATFORM"
# build_for_platform - only main platform
build_for_platform="$BUILD_FOR_PLATFORM"
regenerate_metadata="$REGENERATE_METADATA"

echo "RELEASED = $released"
echo "REPOSITORY_NAME = $rep_name"

# Current path:
# - /home/vagrant/scripts/publish-packages
script_path=`pwd`

# Container path:
# - /home/vagrant/container
container_path=/home/vagrant/container

# /home/vagrant/share_folder contains:
# - http://abf.rosalinux.ru/downloads/rosa2012.1/repository
# - http://abf.rosalinux.ru/downloads/akirilenko_personal/repository/rosa2012.1
platform_path=/home/vagrant/share_folder

repository_path=$platform_path

# See: https://abf.rosalinux.ru/abf/abf-ideas/issues/51
# Move debug packages to special separate repository
# override below if need
use_debug_repo='true'

# Checks 'released' status of platform
status='release'
if [ "$released" == 'true' ] ; then
  status='updates'
fi

# Checks that 'repository' directory exist
mkdir -p $repository_path/{SRPMS,i586,x86_64,armv7l,armv7hl}/$rep_name/$status/media_info
if [ "$use_debug_repo" == 'true' ] ; then
  mkdir -p $repository_path/{SRPMS,i586,x86_64,armv7l,armv7hl}/debug_$rep_name/$status/media_info
fi

sign_rpm=0
gnupg_path=/home/vagrant/.gnupg
if [ ! -d "$gnupg_path" ]; then
  echo "--> $gnupg_path does not exist"
else
  sign_rpm=1
  /bin/bash $script_path/init_rpmmacros.sh
fi


function build_repo {
  path=$1
  arch=$2
  regenerate=$3
  # Build repo
  echo "--> [`LANG=en_US.UTF-8  date -u`] Generating repository..."
  cd $script_path/
  if [ "$regenerate" != 'true' ] ; then
    echo "/usr/bin/genhdlist2 -v --nolock --allow-empty-media --versioned --xml-info $path"
    /usr/bin/genhdlist2 -v --nolock --allow-empty-media --versioned --xml-info "$path"
  else
    echo "/usr/bin/genhdlist2 -v --clean --nolock --allow-empty-media --versioned --xml-info $path"
    /usr/bin/genhdlist2 -v --clean --nolock --allow-empty-media --versioned --xml-info "$path"
  fi
  # Save exit code
  echo $? > "$container_path/$arch.exit-code"
  echo "--> [`LANG=en_US.UTF-8  date -u`] Done."
}

rx=0
arches="SRPMS i586 x86_64 armv7l armv7hl"

# Checks sync status of repository
rep_locked=0
for arch in $arches ; do
  main_folder=$repository_path/$arch/$rep_name
  if [ -f "$main_folder/.repo.lock" ]; then
    rep_locked=1
    break
  else
    touch $main_folder/.publish.lock
  fi
done

# Fails publishing if mirror is currently synchronising the repository state
if [ $rep_locked != 0 ] ; then
  # Unlocks repository for sync
  for arch in $arches ; do
    rm -f $repository_path/$arch/$rep_name/.publish.lock
  done
  echo "--> [`LANG=en_US.UTF-8  date -u`] ERROR: Mirror is currently synchronising the repository state."
  exit 1
fi

file_store_url='http://file-store.rosalinux.ru/api/v1/file_stores'
for arch in $arches ; do
  update_repo=0
  main_folder=$repository_path/$arch/$rep_name
  rpm_backup="$main_folder/$status-rpm-backup"
  rpm_new="$main_folder/$status-rpm-new"
  m_info_backup="$main_folder/$status-media_info-backup"
  rm -rf $rpm_backup $rpm_new $m_info_backup
  mkdir {$rpm_backup,$rpm_new}
  cp -rf $main_folder/$status/media_info $m_info_backup

  if [ "$use_debug_repo" == 'true' ] ; then
    debug_main_folder=$repository_path/$arch/debug_$rep_name
    debug_rpm_backup="$debug_main_folder/$status-rpm-backup"
    debug_rpm_new="$debug_main_folder/$status-rpm-new"
    debug_m_info_backup="$debug_main_folder/$status-media_info-backup"
    rm -rf $debug_rpm_backup $debug_rpm_new $debug_m_info_backup
    mkdir {$debug_rpm_backup,$debug_rpm_new}
    cp -rf $debug_main_folder/$status/media_info $debug_m_info_backup
  fi

  # Downloads new packages
  echo "--> [`LANG=en_US.UTF-8  date -u`] Downloading new packages..."
  new_packages="$container_path/new.$arch.list"
  if [ -f "$new_packages" ]; then
    cd $rpm_new
    for sha1 in `cat $new_packages` ; do
      fullname=`sha1=$sha1 /bin/bash $script_path/extract_filename.sh`
      if [ "$fullname" != '' ] ; then
        curl -O -L "$file_store_url/$sha1"
        mv $sha1 $fullname
        echo $fullname >> "$new_packages.downloaded"
        chown root:root $fullname
        # Add signature to RPM
        if [ $sign_rpm != 0 ] ; then
          chmod 0666 $fullname
          rpm --addsign $rpm_new/$fullname
          # Save exit code
          rc=$?
          if [[ $rc == 0 ]] ; then
            echo "--> Package '$fullname' has been signed successfully."
          else
            echo "--> Package '$fullname' has not been signed successfully!!!"
          fi
        fi
        chmod 0644 $rpm_new/$fullname
      else
        echo "--> Package with sha1 '$sha1' does not exist!!!"
      fi
    done
    update_repo=1
  fi
  echo "--> [`LANG=en_US.UTF-8  date -u`] Done."

  # Creates backup
  echo "--> [`LANG=en_US.UTF-8  date -u`] Creating backup..."
  old_packages="$container_path/old.$arch.list"
  if [ -f "$old_packages" ]; then
    for fullname in `cat $old_packages` ; do
      package=$main_folder/$status/$fullname
      if [ -f "$package" ]; then
        echo "mv $package $rpm_backup/"
        mv $package $rpm_backup/
      fi

      if [ "$use_debug_repo" == 'true' ] ; then
        debug_package=$debug_main_folder/$status/$fullname
        if [ -f "$debug_package" ]; then
          echo "mv $debug_package $debug_rpm_backup/"
          mv $debug_package $debug_rpm_backup/
        fi
      fi

    done
    update_repo=1
  fi
  echo "--> [`LANG=en_US.UTF-8  date -u`] Done."

  # Move packages into repository
  if [ -f "$new_packages" ]; then
    if [ "$use_debug_repo" == 'true' ] ; then
      for file in $( ls -1 $rpm_new/ | grep .rpm$ ) ; do
        rpm_name=`rpm -qp --queryformat %{NAME} $rpm_new/$file`
        if [[ "$rpm_name" =~ debuginfo ]] ; then
          mv $rpm_new/$file $debug_main_folder/$status/
        else
          mv $rpm_new/$file $main_folder/$status/
        fi
      done
    else
      mv $rpm_new/* $main_folder/$status/
    fi
  fi
  rm -rf $rpm_new

  if [ $update_repo != 1 ] ; then
    if [ "$is_container" == 'true' ] ; then
      rm -rf $repository_path/$arch
    fi
    if [ "$regenerate_metadata" != 'true' ] ; then
      continue
    fi
  fi

  build_repo "$main_folder/$status" "$arch" "$regenerate_metadata" &
  if [ "$use_debug_repo" == 'true' ] ; then
    build_repo "$debug_main_folder/$status" "$arch" "$regenerate_metadata" &
  fi
done

# Waiting for genhdlist2...
wait

rc=0
# Check exit codes
for arch in $arches ; do
  path="$container_path/$arch.exit-code"
  if [ -f "$path" ] ; then
    rc=`cat $path`
    if [ $rc != 0 ] ; then
      rpm -qa | grep genhdlist2
      break
    fi
  fi
done


# Check exit code after build and rollback
if [ $rc != 0 ] ; then
  cd $script_path/
  RELEASED=$released REPOSITORY_NAME=$rep_name USE_FILE_STORE=false /bin/bash $script_path/rollback.sh
else
  for arch in $arches ; do
    main_folder=$repository_path/$arch/$rep_name
    rpm_backup="$main_folder/$status-rpm-backup"
    rpm_new="$main_folder/$status-rpm-new"
    m_info_backup="$main_folder/$status-media_info-backup"
    rm -rf $rpm_backup $rpm_new $m_info_backup

    if [ "$use_debug_repo" == 'true' ] ; then
      debug_main_folder=$repository_path/$arch/debug_$rep_name
      debug_rpm_backup="$debug_main_folder/$status-rpm-backup"
      debug_rpm_new="$debug_main_folder/$status-rpm-new"
      debug_m_info_backup="$debug_main_folder/$status-media_info-backup"
      rm -rf $debug_rpm_backup $debug_rpm_new $debug_m_info_backup
    fi

    # Unlocks repository for sync
    rm -f $main_folder/.publish.lock
  done
fi

exit $rc
