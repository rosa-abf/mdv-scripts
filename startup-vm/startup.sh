#!/bin/sh
sudo /bin/bash -c 'echo "195.19.76.240 abf-downloads.rosalinux.ru" >> /etc/hosts'
sudo urpmi.update -a
for p in curl urpmi perl-URPM mock-urpm genhdlist2 tree git rpm ruby ; do
  sudo urpmi --auto $p
done

# sudo usermod -a -G vboxsf vagrant
sudo usermod -a -G  mock vagrant

exit 0