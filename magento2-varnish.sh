#! /bin/bash
# Set up Varnish 4.0, with Magento 2 config. 


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


yum -y install https://repo.varnish-cache.org/redhat/varnish-4.0.el6.rpm
yum -y install varnish



mv /etc/default/varnish.vcl /etc/default/varnish.vcl.packaged
wget https://raw.githubusercontent.com/whyneus/magneto-ponies/master/m2-default.vcl -O /etc/default/varnish.vcl 

MEMORY=$(free -m | grep ^Mem | awk '{print $2}')
sed -i s/^VARNISH_STORAGE_SIZE.*/VARNISH_STORAGE_SIZE=${VARNISHMEMORY}M/g  /etc/sysconfig/varnish
sed -i s/^VARNISH_LISTEN_PORT.*/VARNISH_LISTEN_PORT=80/g /etc/sysconfig/varnish


service varnish restart
chkconfig varnish on