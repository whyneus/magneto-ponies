#! /bin/bash
#
# Script to set PHP-FPM for Magento Web servers
# For RHEL/CentOS 6 or 7
#
# will.parsons@rackspace.co.uk
#


## Sanity check - RHEL/CentOS 6 or 7

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

MAJORVERS=$(head -1 /etc/redhat-release | cut -d"." -f1 | egrep -o '[0-9]')
if [[ "$MAJORVERS"  == "6" ]] || [[ "$MAJORVERS"  == "7" ]]; then
   echo "RHEL/CentOS $MAJORVERS Confirmed."
else
   echo "This script is for RHEL/CentOS 6 or 7 only."
   exit 1
fi


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
  echo " - installing epel-release..."
  yum -q -y install epel-release
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
      iusrelease=$(curl -s https://dl.iuscommunity.org/pub/ius/stable/CentOS/$MAJORVERS/x86_64/ | egrep -o 'href="ius-release.*rpm"' | cut -d'"' -f2)
      echo " - installing ius-release..."
      yum -q -y install https://dl.iuscommunity.org/pub/ius/stable/CentOS/$MAJORVERS/x86_64/$iusrelease      
      rpm --import /etc/pki/rpm-gpg/IUS-COMMUNITY-GPG-KEY
  fi
fi


YUM=`yum repolist | grep ius`
if [[ -z "$YUM" ]];
then
  echo "IUS repositoy failed to install. Please install it manually, then re-run script."
  exit 1
fi


# If PHP version not set by parent, ask the user based on Magento version
if [[ -z $PHPVERS ]]; then

	echo -e "\n\nWhich Major Magento version is to be used?"

	echo "Valid options:
	   1 - Magento 1.x
	   2 - Magento 2.x
"
	read MAJORMAGENTO

	if [[ $MAJORMAGENTO == "2" ]]; then
	    MAGENTO2=true
	    PHPVERS="7.0"
	else
	   if [[ $MAJORVERS == 7 ]]; then 
	      # Stick to the vendor-supported PHP 5.4 for now. 
	      PHPVERS="base"
	   else
	           # For CentOS 6, ask which to install (if not set in a parent script)
		   if [[ -z "$PHPVERS" ]]; then

		      echo -e "\n\nWhich PHP version should be installed?
			    NB: Check compatibility of your Magento version."
		      while true; do
			 echo "Valid options:
				   5.3 - for legacy versions only. 
				   5.4 - for Magento CE 1.6.x / EE 1.11.x  and newer (with patch)
				   5.5 - for Magento CE 1.9.1 / EE 1.14.1 and newer

	"
			 read PHPVERS 
			 if [[ $PHPVERS == "5.5" ]] || [[ $PHPVERS == "5.4" ]]  || [[ $PHPVERS == "5.3" ]]  || [[ $PHPVERS == "7.0" ]];  then
			    break
			 fi
		      done
	            fi
          fi
       fi
fi

# Ask for web server type, if not already set
if [[ -z ${WEBSERVER} ]]; then

echo -ne "\n\nWill you be using Apache (default) or Nginx?
Some developers prefer nginx. If unsure, choose Apache.\n"
while true; do
  echo "enter \"apache\" or \"nginx\" : 
"
  read WEBSERVER

  if [[ $WEBSERVER == "apache" ]] || [[ $WEBSERVER == "nginx" ]] 
  then
    break
  fi
done


fi


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

# Add user if if doesn't exist already
GETENT=$(getent passwd $USERNAME)
if [[ -z ${GETENT} ]]; then
   useradd $USERNAME
fi



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
     if [[ $ENVIRONMENT == "CLOUD" ]];
     then
         sed -i s/^enabled=0/enabled=1/g /etc/yum.repos.d/ius-archive.repo
     fi
     echo "Installing PHP 5.4 ..."
     yum -q -y install php54-gd php54-mysql php54-mcrypt php54-xml php54-xmlrpc php54-mbstring php54-soap php54-pecl-memcache php54-pecl-redis php54-pecl-zendopcache php54-fpm

    # PHP 5.4 specific tweaks
    sed -ri 's/^;?opcache.memory_consumption.*/opcache.memory_consumption=256/g' /etc/php.d/opcache.ini
    sed -ri 's/^;?opcache.max_accelerated_files=.*/opcache.max_accelerated_files=16229/g' /etc/php.d/opcache.ini
fi 

if [[ $PHPVERS == "5.5" ]]; then
    echo "Installing PHP 5.5..."
    yum -q -y install php55u-gd php55u-mysql php55u-mcrypt php55u-xml php55u-xmlrpc php55u-mbstring php55u-soap php55u-pecl-memcache php55u-pecl-redis php55u-opcache php55u-fpm
   # PHP 5.5 specific tweaks
   sed -ri 's/^;?opcache.memory_consumption.*/opcache.memory_consumption=256/g' /etc/php.d/*opcache.ini
   sed -ri 's/^;?opcache.max_accelerated_files=.*/opcache.max_accelerated_files=16229/g' /etc/php.d/*opcache.ini
    
fi

## Need to confirm this...
if [[ $PHPVERS == "5.6" ]]; then
    echo "Installing PHP 5.6..."
    yum -q -y install php56u-process php56u-pear php56u-fpm php56u-mysqlnd php56u-mcrypt php56u-gd php56u-xml php56u-common php56u-pecl-jsonc  php56u-pdo php56u-pecl-redis php56u-opcache php56u-soap php56u-mbstring php56u-xmlrpc php56u-bcmath php56u-cli php56u-pecl-igbinary php56u-pecl-memcache php56u-intl
   # PHP 5.6 specific tweaks
   sed -ri 's/^;?opcache.memory_consumption.*/opcache.memory_consumption=256/g' /etc/php.d/*opcache.ini
   sed -ri 's/^;?opcache.max_accelerated_files=.*/opcache.max_accelerated_files=16229/g' /etc/php.d/*opcache.ini
    
fi

if [[ $PHPVERS == "7.0" ]]; then
  echo "Installing PHP 7.0 ..."
  yum -q -y install php70u-cli php70u-mysqlnd php70u-intl php70u-common php70u-pdo php70u-xmlrpc php70u-devel php70u-fpm php70u-gd php70u-json php70u-soap php70u-gmp php70u-mcrypt php70u-mbstring php70u-xml php70u-bcmath php70u-process php70u-opcache
     # PHP 5.6 specific tweaks
   sed -ri 's/^;?opcache.memory_consumption.*/opcache.memory_consumption=256/g' /etc/php.d/*opcache.ini
   sed -ri 's/^;?opcache.max_accelerated_files=.*/opcache.max_accelerated_files=16229/g' /etc/php.d/*opcache.ini
fi

if [[ $PHPVERS == "base" ]]; then
     echo "Using CentOS 7 base PHP (5.4)..."
     yum -q -y install php-fpm php-gd php-mysql php-mcrypt php-xml php-xmlrpc php-mbstring php-soap php-pecl-memcache php-pecl-redis php-pecl-zendopcache

    # PHP 5.4 specific tweaks
    sed -ri 's/^;?opcache.memory_consumption.*/opcache.memory_consumption=256/g' /etc/php.d/*opcache.ini
    sed -ri 's/^;?opcache.max_accelerated_files=.*/opcache.max_accelerated_files=16229/g' /etc/php.d/*opcache.ini
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

FPMGROUP="php-fpm"


if [[ $(echo "$PHPVERS < 5.6" |bc -l) ]]; then
   FPMGROUP=${WEBSERVER}
fi

echo -e "\nConfiguring PHP-FPM..."
if [[ ! -f /etc/php-fpm.d/${DOMAINNAME}.conf ]]
then
  mv /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.bak
  echo "; Default 'www' pool disabled" > /etc/php-fpm.d/www.conf 
  
  # Work out a sensible pm.max_children
  MEMORY=$(free -m | grep ^Mem | awk '{print $2}')
  MAGENTONEEDS=120  # Average per process. Should be plenty for most
  MAXCHILDREN=$(($MEMORY/$MAGENTONEEDS))
 
  # Hard limits of between 50 - 500
  if [ $MAXCHILDREN -lt 50 ]; then
     MAXCHILDREN=50   # Much less, and we'll just hit the limit all the time
  elif [ $MAXCHILDREN -gt 500 ]; then
     MAXCHILDREN=500  # More than this, and we'll just have too many processes and not enough CPU
  fi  
  
  echo "[${DOMAINNAME}]
listen = /var/run/php-fpm/${DOMAINNAME}.sock
listen.owner = ${USERNAME}
listen.group = ${WEBSERVER}
listen.mode = 0660
user = ${USERNAME}
group = ${FPMGROUP}
pm = dynamic
pm.max_children = ${MAXCHILDREN}
pm.start_servers = 30
pm.min_spare_servers = 30
pm.max_spare_servers = 50
pm.max_requests = 500
php_admin_value[error_log] = /var/log/php-fpm/${DOMAINNAME}-error.log
php_admin_flag[log_errors] = on
php_admin_flag[zlib.output_compression] = On" > /etc/php-fpm.d/${DOMAINNAME}.conf

# Separate pool for Magento admin; allows better resource control. 
echo "[${DOMAINNAME}-admin]
listen = /var/run/php-fpm/${DOMAINNAME}-admin.sock
listen.owner = ${USERNAME}
listen.group = ${WEBSERVER}
listen.mode = 0660
user = ${USERNAME}
group = ${FPMGROUP}
pm = ondemand
pm.max_children = 20
pm.max_requests = 50
php_admin_value[error_log] = /var/log/php-fpm/${DOMAINNAME}-admin-error.log
php_admin_flag[log_errors] = on
php_admin_flag[zlib.output_compression] = Off
php_admin_value[memory_limit] = 2048M" > /etc/php-fpm.d/${DOMAINNAME}-admin.conf




  echo -e "\nDone."
else
  echo -e "Configuration appears to already exist.\nContinuing..."
fi

if [[ $MAJORVERS == "6" ]]; then
   /etc/init.d/php-fpm restart
   chkconfig php-fpm on
fi

if [[ $MAJORVERS == "7" ]]; then
   /bin/systemctl start  php-fpm.service
   /bin/systemctl enable  php-fpm.service
fi


echo "PHP-FPM config complete; the following sockets have been configured:"
ls -al /var/run/php-fpm/*sock

