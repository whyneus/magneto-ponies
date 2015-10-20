#! /bin/bash
#
# Script to set up nginx for Magento.
#
# Relies on PHP sockets: /var/run/php-fpm/${DOMAINNAME}.sock and /var/run/php-fpm/${DOMAINNAME}-admin.sock
# NB: To separate "admin" FPM pool, change "<Location ~ admin>" to "<Location ~ actualAdminPath>". The admin path should be unique for security. 



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




# Ask for domain name if we don't already have it:
if [[ -z ${DOMAINNAME} ]]; then

  echo -ne "\n\nPrimary website domain name (not including \"www\"): "
  read DOMAINNAME
  if [[ -z ${DOMAINNAME} ]]
  then
    echo -e "\nWe need a site to configure PHP-FPM on.\nExiting."
    exit 1
  fi
fi 

# Ask for username if we don't already have it
if [[ -z ${USERNAME} ]]; then
  echo -ne "\nUsername to create (for SSH/SFTP and FPM owner): "
  read USERNAME
  if [[ -z ${USERNAME} ]]
  then 
    echo -e "\nWe need a user to assign to this site.\nExiting."
    exit 1
  fi
fi

# Ask for docroot if we don't already have it
if [[ -z ${DOCROOT} ]]; then
  echo -ne "\nWebsite document root:\nDefault is /var/www/vhosts/$DOMAINNAME/httpdocs : "
  read DOCROOT
  if [[ -z ${DOCROOT} ]]
  then
    DOCROOT="/var/www/vhosts/$DOMAINNAME/httpdocs"
  fi
fi


# Add user if if doesn't exist already
GETENT=$(getent passwd $USERNAME)
if [[ -z ${GETENT} ]]; then
  USERPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n1)
  mkdir -p $DOCROOT
  cd $DOCROOT
  cd ..
  HOMEDIR=$(pwd)
  useradd -d $HOMEDIR ${USERNAME}
  echo ${USERPASS} | passwd --stdin ${USERNAME}
  chmod o+x $HOMEDIR $DOCROOT
  chown -R ${USERNAME}:${USERNAME} $HOMEDIR
  NEWUSER=1
fi


# Remove Apache, if it's there. 
yum -y remove httpd

# Install NginX repo
# https://www.nginx.com/resources/wiki/start/topics/tutorials/install/

if [[ grep -qi "Red Hat" /etc/redhat-release ]]; then
  echo "[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/rhel/6/$basearch/
gpgcheck=0
enabled=1" > /etc/yum.repos.d/nginx.repo

else echo "[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/rhel/6/$basearch/
gpgcheck=0
enabled=1"  > /etc/yum.repos.d/nginx.repo
fi

yum install nginx
