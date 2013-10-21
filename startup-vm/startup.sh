#!/bin/sh
sudo /bin/bash -c 'echo "195.19.76.240 abf-downloads.rosalinux.ru" >> /etc/hosts'
sudo urpmi.update -a
PACKAGES=(curl urpmi perl-URPM mock-urpm genhdlist2 tree git rpm ruby)
sudo urpmi ${PACKAGES[*]} --auto --no-suggests --no-verify-rpm

# sudo usermod -a -G vboxsf vagrant
sudo usermod -a -G  mock-urpm vagrant

exit 0