#!/bin/sh
# Increase Disk IO performance 
sudo /bin/bash -c 'echo noop > /sys/block/vda/queue/scheduler'

sudo /bin/bash -c 'echo "195.19.76.240 abf-downloads.rosalinux.ru" >> /etc/hosts'

sudo urpmi.update -a
PACKAGES=(wget curl urpmi perl-URPM mock-urpm genhdlist2 tree git rpm ruby python-rpm5utils python-rpm urpm-tools)

# We will rerun update of crucial packages in case when repository is modified in the middle,
# but for safety let's limit number of retest attempts
# (since in case when repository metadata is really broken we can loop here forever)
MAX_RETRIES=25
WAIT_TIME=60
RETRY_GREP_STR="You may need to update your urpmi database\|problem reading synthesis file of medium\|retrieving failed: "

try_rerun=true
retry=0
while $try_rerun
do
  sudo urpmi ${PACKAGES[*]} --downloader wget --wget-options --auth-no-challenge --auto --no-suggests --no-verify-rpm --ignorearch > /tmp/update.log 2>&1
  test_code=$?
  try_rerun=false
  if [[ $test_code != 0 && $retry < $MAX_RETRIES ]] ; then
    if grep -q "$RETRY_GREP_STR" /tmp/update.log; then
      echo '--> Repository was changed in the middle, will relaunch update of crucial packages'
      sleep $WAIT_TIME
      sudo urpmi.update -a
      try_rerun=true
      (( retry=$retry+1 ))
    fi
  fi
done

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
