#! /bin/bash
#
# CentOS 6 Web Stack
# will.parsons@rackspace.co.uk
#


## Sanity check - RHEL6 or CentOS 6

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


## Environment check - Cloud or Dedicated?

ENVIRONMENT="CLOUD";
if [[ -f /root/.rackspace/server_number ]]; then
  ENVIRONMENT="DEDICATED"
fi



echo -e "\nChecking repositories..."

# Repo check - EPEL

YUM=`yum repolist | grep -i epel`
if [[ ! -z "$YUM" ]];
then
  echo " - EPEL found."
else
  echo " - installing rs-epel-release..."
  yum -q -y install rs-epel-release
fi

YUM=`yum repolist | grep -i epel`
if [[ -z "$YUM" ]];
then
  echo "EPEL install failed. Please install it manually, then re-run script."
  exit 1
fi




## Repo check - IUS

YUM=`yum repolist | grep ius`
if [[ ! -z "$YUM" ]];
then
  echo " - IUS found."
else
  if [[ $ENVIRONMENT == "DEDICATED" ]];
  then
      # This is a Dedicated server - advise on RHN repo end exit. 
      echo "Server must be subscribed to IUS repository via Rackspace managed RHN channels."
      exit 1
  else
      # Cloud server - install IUS from repo
      iusrelease=$(curl -s http://dl.iuscommunity.org/pub/ius/stable/CentOS/6/x86_64/ | grep ius-release | cut -d'"' -f8)
      echo " - installing ius-release..."
      yum -q -y install http://dl.iuscommunity.org/pub/ius/stable/CentOS/6/x86_64/$iusrelease      
      rpm --import /etc/pki/rpm-gpg/IUS-COMMUNITY-GPG-KEY
  fi
fi


YUM=`yum repolist | grep ius`
if [[ -z "$YUM" ]];
then
  echo "IUS repositoy failed to install. Please install it manually, then re-run script."
  exit 1
fi



echo -e "\n\nWhich PHP version should be installed?
NB: Check compatibility of your Magento version."

while true; do
  echo "Valid options:
   5.3 - for legacy versions only. 
   5.4 - for Magneto CE 1.6.x / EE 1.11.x  and newer (with patch)
   5.5 - for Magento CE 1.9.1 / EE 1.14.1 and newer  
"
  read PHPVERS

  if [[ $PHPVERS == "5.5" ]] || [[ $PHPVERS == "5.4" ]]  || [[ $PHPVERS == "5.3" ]]
  then
    break
  fi
done


echo -ne "\n\nPrimary website domain name (not including \"www\"): "
read DOMAINNAME
if [[ -z ${DOMAINNAME} ]]
then
  echo -e "\nWe need a site to configure PHP-FPM on.\nExiting."
  exit 1
fi

echo -ne "\nUsername to create (for SSH/SFTP and FPM owner): "
read FTPUSER
if [[ -z ${FTPUSER} ]]
then
  echo -e "\nWe need a user to assign to this site.\nExiting."
  exit 1
fi




echo -e "\n\n\n\n-------------------------\n\nSANITY CHECK:

  Domain     : $DOMAINNAME
  User       : $FTPUSER
  PHP version: $PHPVERS

NB: if PHP is already installed, this script will remove all config and replace with $PHPVERS optimised for Magento.)
"



echo -en '\n\nType "yes" to proceed... '


read PROCEED
if  [[ $PROCEED != "yes" ]]; then
    echo "Exiting."
    exit 0   
fi


echo -e "Proceeding with install...\n\n"

## First, some packages we might want/need. 
yum -y -q install git vim jwhois telnet nc mlocate memcached
yum -y remove dovecot >/dev/null 2>&1

# REMOVE any existing PHP packages
CURRENTPHP=$(rpm -qa | grep ^php)
if [[ ${CURRENTPHP} ]]; then
    echo "Removing current PHP packages..."
    yum -q -y remove "php*"
fi

if [ -e /etc/php.ini ] || [ -e /etc/php.d ]; then
    # Just in case, back up any existing config, 
    # moving it out of the way so we definitely have a blank canvas.
    OLDCONFIG="/root/php-config-before-magento/"
    echo "Moving old PHP config to $OLDCONFIG"
    mkdir $OLDCONFIG
    mv /etc/php* $OLDCONFIG
fi

if [[ $PHPVERS == "5.3" ]]; then
     echo "Installing PHP 5.3 (with APC)..."
     yum -q -y install php-fpm php-gd php-mysql php-mcrypt php-xml php-xmlrpc php-mbstring php-soap php-pecl-memcache php-pecl-redis php-pecl-apc

     # PHP 5.3 specific tweaks
     sed -ri 's/^;?apc.shm_size.*/apc.shm_size=256M/g' /etc/php.d/apc.ini
fi

if [[ $PHPVERS == "5.4" ]]; then
     echo "Installing PHP 5.4..."
     yum -q -y install php54-gd php54-mysql php54-mcrypt php54-xml php54-xmlrpc php54-mbstring php54-soap php54-pecl-memcache php54-pecl-redis php54-pecl-zendopcache php54-fpm

    # PHP 5.4 specific tweaks
    sed -ri 's/^;?opcache.memory_consumption.*/opcache.memory_consumption=256/g' /etc/php.d/opcache.ini
    sed -ri 's/^;?opcache.max_accelerated_files=4000.*/opcache.max_accelerated_files=16229/g' /etc/php.d/opcache.ini
fi 

if [[ $PHPVERS == "5.5" ]]; then
    echo "Installing PHP 5.5..."
    yum -q -y install php55u-gd php55u-mysql php55u-mcrypt php55u-xml php55u-xmlrpc php55u-mbstring php55u-soap php55u-pecl-memcache php55u-pecl-redis php55u-pecl-zendopcache php55u-fpm
   # PHP 5.5 specific tweaks
   sed -ri 's/^;?opcache.memory_consumption.*/opcache.memory_consumption=256/g' /etc/php.d/*opcache.ini
   sed -ri 's/^;?opcache.max_accelerated_files=4000.*/opcache.max_accelerated_files=16229/g' /etc/php.d/*opcache.ini
    
fi

# Generic PHP tweaks

TIMEZONE=`cat /etc/sysconfig/clock | grep ZONE | cut -d\" -f2`
echo -e "\nConfiguring PHP."
if [[ -z ${TIMEZONE} ]]
then
  TIMEZONE="UTC"
fi
sed -i 's/^safe_mode =.*/safe_mode = Off/g' /etc/php.ini
sed -ri "s~^;?date.timezone =.*~date.timezone = ${TIMEZONE}~g" /etc/php.ini
sed -i 's/^; *realpath_cache_size.*/realpath_cache_size = 128K/g' /etc/php.ini
sed -i 's/^; *realpath_cache_ttl.*/realpath_cache_ttl = 7200/g' /etc/php.ini
sed -i 's/^memory_limit.*/memory_limit = 512M/g' /etc/php.ini
sed -i 's/^max_execution_time.*/max_execution_time = 1800/g' /etc/php.ini
sed -i 's/^expose_php.*/expose_php = off/g' /etc/php.ini
echo -e "\nPHP configuration complete."

php -v






### Apache mod_fastcgi install


HTTPDDEVEL=`rpm -qa | grep -e "httpd.*devel.*"`
echo -e "\nIntalling Apache mod_fastcgi..."
if [[ -z ${HTTPDDEVEL} ]]
then
  yum -q -y install httpd-devel httpd mod_ssl
fi

sed -i s/^ServerTokens\ OS/ServerTokens\ Prod/g /etc/httpd/conf/httpd.conf

PREPDIRCHECK=`ls /home/rack/ | grep magentowebsetup`
if [[ -z "$PREPDIRCHECK" ]]
then
  PREPDIRREUSE="0"
  PREPDIR="/home/rack/magentowebsetup-`date +%Y%m%d`_`/bin/date +%H%M`"
  echo -e "\nCreating prep directory.\nOur working directory will be ${PREPDIR}."
  mkdir -p $PREPDIR
else
  PREPDIRREUSE="1"
  PREPDIR="/home/rack/${PREPDIRCHECK}"
  echo -e "\nPrevious prep directory detected.\nReusing ${PREPDIR}."
fi

MODFCGI=`ls -1 /usr/lib64/httpd/modules/ | grep fastcgi`
GCCINSTALLED=`command -v gcc`
MAKEINSTALLED=`command -v make`
echo -e "\nInstalling mod_fastcgi..."
if [[ ${PREPDIRREUSE}="1" ]]
then
  wget -q -P ${PREPDIR} 'http://www.fastcgi.com/dist/mod_fastcgi-SNAP-0910052141.tar.gz'
  tar -zxC ${PREPDIR} -f ${PREPDIR}/mod_fastcgi-SNAP-0910052141.tar.gz
fi
if [[ -z ${MODFCGI} ]]
then
  if [[ -z ${MAKEINSTALLED} ]] || [[ -z ${GCCINSTALLED} ]]
  then
    yum -q -y install make gcc
  fi
  cd ${PREPDIR}/mod_fastcgi-*
  make -f Makefile.AP2 top_dir=/usr/lib64/httpd
  cp .libs/mod_fastcgi.so /usr/lib64/httpd/modules/
  echo "LoadModule fastcgi_module /usr/lib64/httpd/modules/mod_fastcgi.so" > /etc/httpd/conf.d/fastcgi.conf
else
  echo -e "\nModule already appears to be installed.\nContinuing..."
fi
echo "# mod_fastcgi in use for PHP-FPM. This file here to prevent 'php' package creating new config." > /etc/httpd/conf.d/php.conf



USERPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n1)
USEREXIST=`id ${FTPUSER} 2>&1 >/dev/null`
echo -e "\nCreating user ${FTPUSER}..."
if [[ -z ${USEREXIST} ]]
then
  echo -e "\nUser already exists.\nCheck that it has permissions to access to /var/www/vhosts/${DOMAINNAME}.\nContinuing..."
else
  mkdir -p /var/www/vhosts
  useradd -d /var/www/vhosts/${DOMAINNAME} ${FTPUSER}
  echo ${USERPASS} | passwd --stdin ${FTPUSER}
  chmod o+x /var/www/vhosts/${DOMAINNAME}
  mkdir /var/www/vhosts/${DOMAINNAME}/httpdocs
  chown ${FTPUSER}:${FTPUSER} /var/www/vhosts/${DOMAINNAME}/httpdocs
  NEWUSER=1
fi

echo -e "\nConfiguring PHP-FPM..."
if [[ ! -f /etc/php-fpm.d/${DOMAINNAME}.conf ]]
then
  mv /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.bak
  echo "# Default 'www' pool disabled" > /etc/php-fpm.d/www.conf 
  echo "[${DOMAINNAME}]
listen = /var/run/php-fpm/${DOMAINNAME}.sock
listen.owner = ${FTPUSER}
listen.group = apache
listen.mode = 0660
user = ${FTPUSER}
group = apache
pm = dynamic
pm.max_children = 100
pm.start_servers = 30
pm.min_spare_servers = 30
pm.max_spare_servers = 100
pm.max_requests = 500
php_admin_value[error_log] = /var/log/php-fpm/${DOMAINNAME}-error.log
php_admin_flag[log_errors] = on
php_admin_flag[zlib.output_compression] = On" > /etc/php-fpm.d/${DOMAINNAME}.conf
  if [[ ! -f /var/run/php-fpm/php-fpm.pid ]]
  then
    /etc/init.d/php-fpm start
  else
    /etc/init.d/php-fpm reload
  fi
  echo -e "\nDone."
else
  echo -e "Configuration appears to already exist.\nContinuing..."
fi

HOSTNAME=`hostname`
VHOSTEXISTS=`httpd -S 2>&1 | grep -v ${HOSTNAME} | grep ${DOMAINNAME}`
if [[ -z ${VHOSTEXISTS} ]]
then
  NAMEDBASEDEXISTS=`grep -e ^NameVirt -R /etc/httpd/`
  INCLUDEEXISTS=`grep -e ^Include.*vhosts\.d.*conf -R /etc/httpd/`
  if [[ -z ${NAMEDBASEDEXISTS} ]]
  then
    echo -e "\nNameVirtualHost *:80" >> /etc/httpd/conf/httpd.conf
  fi
  if [[ -z ${INCLUDEEXISTS} ]]
  then
    echo -e "\nInclude vhosts.d/*.conf" >> /etc/httpd/conf/httpd.conf
  fi
fi

if [[ -z ${VHOSTEXISTS} ]] && [[ "${DOMAINNAME}" != www.* ]]
then
  mkdir -p /etc/httpd/vhosts.d
  echo "<VirtualHost *:80>
  ServerName ${DOMAINNAME}
  ServerAlias www.${DOMAINNAME}
  DocumentRoot /var/www/vhosts/${DOMAINNAME}/httpdocs
  SetEnvIf X-Forwarded-Proto https HTTPS=on

  <Directory /var/www/vhosts/${DOMAINNAME}/httpdocs>
    AllowOverride All
    Options +FollowSymLinks
    SetOutputFilter DEFLATE
    BrowserMatch ^Mozilla/4 gzip-only-text/html
    BrowserMatch ^Mozilla/4\.0[678] no-gzip
    BrowserMatch \bMSIE !no-gzip !gzip-only-text/html
    SetEnvIfNoCase Request_URI \.(?:gif|jpe?g|png)$ no-gzip dont-vary
    Header append Vary: Accept-Encoding
    ExpiresActive On
    ExpiresDefault \"access plus 1 month\"
  </Directory>


  # Allow web fonts across parallel hostnames
  <FilesMatch \"\.(ttf|otf|eot|svg|woff)$\">
      <IfModule mod_headers.c>
      Header set Access-Control-Allow-Origin "*"
      </IfModule>
  </FilesMatch>

  CustomLog /var/log/httpd/${DOMAINNAME}-access_log combined
  ErrorLog /var/log/httpd/${DOMAINNAME}-error_log

  <IfModule mod_fastcgi.c>
    AddHandler php5-fcgi .php
    Action php5-fcgi /php5-fcgi
    Alias /php5-fcgi /dev/shm/${DOMAINNAME}.fcgi
    FastCGIExternalServer /dev/shm/${DOMAINNAME}.fcgi -socket /var/run/php-fpm/${DOMAINNAME}.sock -flush -idle-timeout 1800
  </IfModule>
</VirtualHost>" > /etc/httpd/vhosts.d/${DOMAINNAME}.conf
elif [[ -z ${VHOSTEXISTS} ]] && [[ "${DOMAINNAME}" == www.* ]]
then
  mkdir -p /etc/httpd/vhosts.d
  echo "<VirtualHost *:80>
  ServerName `echo ${DOMAINNAME} | sed 's/^www\.//g'`
  ServerAlias ${DOMAINNAME}
  DocumentRoot /var/www/vhosts/`echo ${DOMAINNAME} | sed 's/^www\.//g'`/httpdocs
  SetEnvIf X-Forwarded-Proto https HTTPS=on

  <Directory /var/www/vhosts/`echo ${DOMAINNAME} | sed 's/^www\.//g'`/httpdocs>
    AllowOverride All
    Options +FollowSymLinks
    SetOutputFilter DEFLATE
    BrowserMatch ^Mozilla/4 gzip-only-text/html
    BrowserMatch ^Mozilla/4\.0[678] no-gzip
    BrowserMatch \bMSIE !no-gzip !gzip-only-text/html
    SetEnvIfNoCase Request_URI \.(?:gif|jpe?g|png)$ no-gzip dont-vary
    Header append Vary User-Agent env=!dont-vary
    ExpiresActive On
    ExpiresDefault \"access plus 1 month\"
  </Directory>

  # Allow web fonts across parallel hostnames
  <FilesMatch \"\.(ttf|otf|eot|svg|woff)$\">
      <IfModule mod_headers.c>
      Header set Access-Control-Allow-Origin "*"
      </IfModule>
  </FilesMatch>

  CustomLog /var/log/httpd/`echo ${DOMAINNAME} | sed 's/^www\.//g'`-access_log combined
  ErrorLog /var/log/httpd/`echo ${DOMAINNAME} | sed 's/^www\.//g'`-error_log

  <IfModule mod_fastcgi.c>
    AddHandler php5-fcgi .php
    Action php5-fcgi /php5-fcgi
    Alias /php5-fcgi /dev/shm/`echo ${DOMAINNAME} | sed 's/^www\.//g'`.fcgi
    FastCGIExternalServer /dev/shm/`echo ${DOMAINNAME} | sed 's/^www\.//g'`.fcgi -socket /var/run/php-fpm/`echo ${DOMAINNAME} | sed 's/^www\.//g'`.sock -flush -idle-timeout 1800
  </IfModule>
</VirtualHost>" > /etc/httpd/vhosts.d/`echo ${DOMAINNAME} | sed 's/^www\.//g'`.conf
else
  echo -e "Virtual host for ${DOMAINNAME} appears to exist.\nNot replacing.\nContinuing..."
fi







# Redis Cleanup script 
HOMEDIR=$(getent passwd $FTPUSER | cut -d':' -f6)
cd $HOMEDIR
git clone https://github.com/samm-git/cm_redis_tools.git
cd cm_redis_tools
git submodule update --init --recursive

# Create the cron job, and the main Magento Cron while we're here
echo "## Redis cleanup job
33 2 * * * /usr/bin/php $HOMEDIR/cm_redis_tools/rediscli.php -s 127.0.0.1 -p 6379 -d 0,1,2

## Main Magento cron job
*/5 * * * * /bin/bash $HOMEDIR/httpdocs/cron.sh" >> /tmp/rediscron
crontab -l -u $FTPUSER | cat - /tmp/rediscron | crontab -u $FTPUSER -





## Service config
for service in php-fpm httpd; do
   chkconfig $service on
   service $service restart
done

## iptables for Cloud servers
if [[ $ENVIRONMENT == "CLOUD" ]]; then
    iptables -I INPUT -s 10.0.0.0/8 -p tcp --dport 80 -j ACCEPT
    service iptables save
fi



## INFORMATION OUTPUT

echo "



Setup complete. 

This server IP: $(curl -4 icanhazip.com --max-time 3)
SSH Username  : $FTPUSER
SSH Password  : $USERPASS
Home Directory: /var/www/vhosts/$DOMAINNAME/
Web doc root  : /var/www/vhosts/$DOMAINNAME/httpdocs/

" 

