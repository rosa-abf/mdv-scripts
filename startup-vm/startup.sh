#!/bin/sh

sudo urpmi.update -a
for p in urpmi mock-urpm genhdlist2 tree ; do
  sudo urpmi --auto $p
done

sudo /bin/bash -c 'echo "185.4.234.68 file-store.rosalinux.ru" >> /etc/hosts'
sudo /bin/bash -c 'echo "195.19.76.241 abf.rosalinux.ru" >> /etc/hosts'

exit 0