#! /bin/bash
# Set up Varnish 4.0, with Magento 2 config. 


MAJORVERS=$(head -1 /etc/redhat-release | cut -d"." -f1 | egrep -o '[0-9]')
if [[ "$MAJORVERS"  == "6" ]] || [[ "$MAJORVERS"  == "7" ]]; then
   echo "RHEL/CentOS $MAJORVERS Confirmed."
else
   echo "This script is for RHEL/CentOS 6 or 7 only."
   exit 1
fi



echo -e "\nChecking EPEL repository."

# Repo check - EPEL

YUM=`yum repolist | grep -i epel`
if [[ ! -z "$YUM" ]];
then
  echo " - EPEL found."
else
  echo " - installing epel-release..."
  yum -q -y install epel-release
fi

YUM=`yum repolist | grep -i epel`
if [[ -z "$YUM" ]];
then
  echo "EPEL install failed. Please install it manually, then re-run script."
  exit 1
fi


yum -y install https://repo.varnish-cache.org/redhat/varnish-4.0.el${MAJORVERS}.rpm
yum -y install varnish



mv /etc/varnish/default.vcl /etc/varnish/default.vcl.packaged
wget https://raw.githubusercontent.com/whyneus/magneto-ponies/master/m2-default.vcl -O /etc/varnish/default.vcl 



# By default, use 1/4 of server memory
MEMORY=$(free -m | grep ^Mem | awk '{print $2}')
VARNISHMEMORY=$(($MEMORY/4))

if [[ $MAJORVERS == "6" ]]; then

   sed -i s/^VARNISH_LISTEN_PORT.*/VARNISH_LISTEN_PORT=80/g /etc/sysconfig/varnish
   sed -i s/^VARNISH_STORAGE_SIZE.*/VARNISH_STORAGE_SIZE=${VARNISHMEMORY}M/g  /etc/sysconfig/varnish

   /etc/init.d/varnish restart
   chkconfig varnish on
fi

if [[ $MAJORVERS == "7" ]]; then
    sed -i s/^VARNISH_STORAGE=.*/VARNISH_STORAGE=\"malloc,${VARNISHMEMORY}M\"/g  /etc/varnish/varnish.params
    sed -i s/^VARNISH_LISTEN_PORT.*/VARNISH_LISTEN_PORT=80/g /etc/varnish/varnish.params

   /bin/systemctl restart  varnish.service
   /bin/systemctl enable  varnish.service
fi
