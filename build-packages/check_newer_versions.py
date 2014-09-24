#!/usr/bin/python2

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

# We will check all packages and set exit_code to 1
# if some of them fail the test
exit_code = 0

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

#   Useful for local tests without chrooting
#    p = os.popen("urpmq --evrd " + name + " 2>&1 | sed 's/|/\\n/g'")

    p = os.popen("sudo chroot " + chroot_path + " urpmq --wget --wget-options --auth-no-challenge --evrd " + name + " 2>&1 | sed 's/|/\\n/g'")
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
            # urpmq output line is not recognized - just print it "as is"
            print existing_pkg
            continue

        res = rpm5utils.miscutils.compareDEVR( (distepoch, epoch, version, release), (ex_distepoch, ex_epoch, ex_version, ex_release) )
        if res < 1:
            print "A package with the same name (" + name + ") and same or newer version (" + evrd + ") already exists in repositories!"
            exit_code = 1
            # Matching package has been found - no need to parse other lines of "urpmq --evrd"
            break

    del hdr
    os.close(fdno)

del ts

sys.exit(exit_code)

