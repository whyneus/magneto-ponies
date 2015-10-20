#! /bin/bash
#
# Script to set up Apache for Magento. 
# Compiles mod_fastcgi for use with PHP-FPM. 
#


## Sanity checks - root on RHEL6 or CentOS 6

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

MAJORVERS=$(head -1 /etc/redhat-release | cut -d"." -f1 | egrep -o '[0-9]')
if [ "$MAJORVERS"  != 6 ]; then
   echo "This script is for CentOS 6 / RHEL 6  only."
   exit 1
fi
echo "RHEL/CentOS 6 Confirmed."

