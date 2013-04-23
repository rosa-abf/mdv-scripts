#!/bin/sh

sudo urpmi.update -a
for p in urpmi mock-urpm genhdlist2 tree ; do
  sudo urpmi --auto $p
done

usermod -a -G vboxsf vagrant

exit 0