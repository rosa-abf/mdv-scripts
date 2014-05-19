#!/usr/bin/python

#
# Read all rpm packages in chroot directory and check
# if packages with newer or same version are available in repositories
#
# If yes, fail the test (return non-zero)
#

import sys
import glob
import os.path
import rpm
import rpm5utils.miscutils

if len(sys.argv) < 2:
    sys.exit('Usage: %s chroot_path' % sys.argv[0])

chroot_path = sys.argv[1]

ts = rpm.TransactionSet()
ts.setVSFlags(~(rpm.RPMVSF_NEEDPAYLOAD))

for pkg in glob.glob(chroot_path + "/*.rpm"):
    # Do not check src.srm
    # (can't exclude them in the glob expression above,
    #  since glob doesn't support exclusion patterns)
    if os.path.basename(pkg).endswith("src.rpm"):
        continue

    fdno = os.open(pkg, os.O_RDONLY)

    hdr = ts.hdrFromFdno(fdno)
    name = hdr['name']
    version = hdr['version']
    release = hdr['release']
    if hdr['epoch']:
        epoch = hdr['epoch']
    else:
        epoch = 0
    if hdr['distepoch']:
        distepoch = hdr['distepoch']
    else:
        distepoch = 0

    # Add all distribution media
    os.system("sudo chroot " + chroot_path + " urpmi.addmedia --urpmi-root test_root --distrib --mirrorlist")

    # Enable and update ignored media
    active_media = os.popen("sudo chroot " + chroot_path + " urpmq --root test_root --list-media active").readlines()
    p = os.popen("sudo chroot " + chroot_path + " urpmq --list-media")
    for rep in p.readlines():
        if rep not in active_media:
            os.system("sudo chroot " + chroot_path + " urpmi.update --urpmi-root test_root --no-ignore '" + rep + "'")
            os.system("sudo chroot " + chroot_path + " urpmi.update --urpmi-root test_root '" + rep + "'")

#   Useful for local tests without chrooting
#    p = os.popen("urpmq --evrd " + name + " 2>&1 | sed 's/|/\\n/g'")

    p = os.popen("sudo chroot " + chroot_path + " urpmq --root test_root --evrd " + name + " 2>&1 | sed 's/|/\\n/g'")
    for existing_pkg in p.readlines():
        if "Unknown option:" in existing_pkg:
            print "This urpmq doesn't support --evrd option, the test will be skipped"
            sys.exit(0)

        # existing_pkg should look like "name: epoch:version-release:distepoch"
        try:
            (name, evrd) = existing_pkg.split()
            evrd_array = evrd.split(":")
            ex_epoch = evrd_array[0]
            ex_distepoch = evrd_array[2]
	    (ex_version, ex_release) = evrd_array[1].split("-")
        except:
            print "Internal error, skipping the test..."
            sys.exit(0)

        res = rpm5utils.miscutils.compareDEVR( (distepoch, epoch, version, release), (ex_distepoch, ex_epoch, ex_version, ex_release) )
        if res < 1:
            print "A package with the same name and same or newer version (" + evrd + ") already exists in repositories!"
            del hdr
            os.close(fdno)
            del ts
            sys.exit(1)

    del hdr
    os.close(fdno)

del ts
