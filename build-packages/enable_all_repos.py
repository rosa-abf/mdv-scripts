#!/usr/bin/python

#
# Enable all repositories inside the chroot using given mirrorlist
#
# Arguments: chroot_path, mirrorlist
#

import sys
import glob
import os.path

if len(sys.argv) < 3:
    sys.exit('Usage: %s chroot_path mirrorlist_url' % sys.argv[0])

chroot_path = sys.argv[1]
mirrorlist  = sys.argv[2]

# Add all distribution media
print(" ... updating distribution list from " + mirrorlist)
os.system("sudo chroot " + chroot_path + " urpmi.addmedia --wget --wget-options --auth-no-challenge --debug --distrib --mirrorlist " + mirrorlist)

# Enable and update ignored media
active_media = os.popen("sudo chroot " + chroot_path + " urpmq --wget --wget-options --auth-no-challenge --debug --list-media active").readlines()
p = os.popen("sudo chroot " + chroot_path + " urpmq --wget --wget-options --auth-no-challenge --debug --list-media")
for rep in p.readlines():
    if rep not in active_media:
	rep = rep.rstrip()
        os.system("sudo chroot " + chroot_path + " urpmi.update --wget --wget-options --auth-no-challenge --debug --no-ignore '" + rep + "'")
        os.system("sudo chroot " + chroot_path + " urpmi.update --wget --wget-options --auth-no-challenge --debug '" + rep + "'")
