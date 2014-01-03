#!/bin/sh

echo '--> mdv-scripts/publish-packages: init_rpmmacros.sh'

gnupg_path=/home/vagrant/.gnupg

gpg --list-keys
cp -f $gnupg_path/* /root/.gnupg/
gpg --list-keys
rpmmacros=~/.rpmmacros

rm -f $rpmmacros
keyname=`gpg --list-public-keys --homedir $gnupg_path | sed -n 3p | awk '{ print $2 }' | awk '{ sub(/.*\//, ""); print }'`
echo "%_signature gpg"        >> $rpmmacros
echo "%_gpg_name $keyname"    >> $rpmmacros
echo "%_gpg_path $gnupg_path" >> $rpmmacros
echo "%_gpgbin /usr/bin/gpg"  >> $rpmmacros
echo "%__gpg /usr/bin/gpg"    >> $rpmmacros
echo "--> keyname: $keyname"
exit 0