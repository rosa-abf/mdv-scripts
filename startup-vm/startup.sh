#!/bin/sh

sudo urpmi.update -a
for p in urpmi perl-URPM mock-urpm genhdlist2 tree ; do
  sudo urpmi --auto $p
done

sudo usermod -a -G vboxsf vagrant

exit 0