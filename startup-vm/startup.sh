#!/bin/sh
sudo /bin/bash -c 'echo "195.19.76.240 abf-downloads.rosalinux.ru" >> /etc/hosts'
sudo urpmi.update -a
PACKAGES=(wget curl urpmi perl-URPM mock-urpm genhdlist2 tree git rpm ruby)
sudo urpmi ${PACKAGES[*]} --auto --no-suggests --no-verify-rpm --ignorearch

# sudo usermod -a -G vboxsf vagrant
sudo usermod -a -G  mock-urpm vagrant
sudo cp -f  /usr/share/zoneinfo/UTC /etc/localtime

# ABF_DOWNLOADS_PROXY, see: /etc/profile
if [ "$ABF_DOWNLOADS_PROXY" != '' ] ; then
  sudo /bin/bash -c "echo 'export http_proxy=$ABF_DOWNLOADS_PROXY' >> /etc/profile"

  sudo /bin/bash -c "echo 'http_proxy=$ABF_DOWNLOADS_PROXY'   >> /etc/urpmi/proxy.cfg"
  sudo /bin/bash -c "echo 'ftp_proxy=$ABF_DOWNLOADS_PROXY'    >> /etc/urpmi/proxy.cfg"
  sudo /bin/bash -c "echo 'https_proxy=$ABF_DOWNLOADS_PROXY'  >> /etc/urpmi/proxy.cfg"
fi

exit 0
