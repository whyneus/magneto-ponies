#! /bin/bash
#
# Script to set up our stack on a single server
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
read USERNAME
if [[ -z ${USERNAME} ]]
then
  echo -e "\nWe need a user to assign to this site.\nExiting."
  exit 1
fi


echo -ne "\nIs the Database going to be on this server? 
(script will install and configure Percona 5.6) 

[Y/N] ?   "
read DBSERVER
if [[ $DBSERVER == "y" ]] ||  [[ $DBSERVER == "Y" ]]; then
    DBSERVER=1

    echo -ne "\nDatabase Name to create (leave blank if no new DB required): "
    read DBNAME
else 
    DBSERVER=0
fi

echo -e "\n\n\n\n-------------------------\n\nSANITY CHECK:

  Domain     : $DOMAINNAME
  User       : $USERNAME
  PHP version: $PHPVERS

NB: if PHP is already installed, this script will remove all config and replace with $PHPVERS optimised for Magento.)
"

if [[ $DBSERVER == 1 ]]; then
  echo "
  Database   : Install and configure Percona 5.6"
  if [[ ! -z ${DBNAME} ]]; then
    echo "  DB Name    : $DBNAME"
    echo "  DB User    : $USERNAME"
  else
    echo "               but do not create a database"
  fi
else
  echo "
Database: Not required on this server
"
fi

echo -en '\n\nType "yes" to proceed... '


read PROCEED
if  [[ $PROCEED != "yes" ]]; then
    echo "Exiting."
    exit 0   
fi


echo -e "Proceeding with install...\n\n"

## First, some packages we might want/need. 
yum -y -q install git vim jwhois telnet nc mlocate memcached
yum remove dovecot >/dev/null 2>&1

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
USEREXIST=`id ${USERNAME} 2>&1 >/dev/null`
echo -e "\nCreating user ${USERNAME}..."
if [[ -z ${USEREXIST} ]]
then
  echo -e "\nUser already exists.\nCheck that it has permissions to access to /var/www/vhosts/${DOMAINNAME}.\nContinuing..."
else
  mkdir -p /var/www/vhosts
  useradd -d /var/www/vhosts/${DOMAINNAME} ${USERNAME}
  echo ${USERPASS} | passwd --stdin ${USERNAME}
  chmod o+x /var/www/vhosts/${DOMAINNAME}
  mkdir /var/www/vhosts/${DOMAINNAME}/httpdocs
  chown ${USERNAME}:${USERNAME} /var/www/vhosts/${DOMAINNAME}/httpdocs
  NEWUSER=1
fi

echo -e "\nConfiguring PHP-FPM..."
if [[ ! -f /etc/php-fpm.d/${DOMAINNAME}.conf ]]
then
  mv /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.bak
  echo "# Default 'www' pool disabled" > /etc/php-fpm.d/www.conf 
  echo "[${DOMAINNAME}]
listen = /var/run/php-fpm/${DOMAINNAME}.sock
listen.owner = ${USERNAME}
listen.group = apache
listen.mode = 0660
user = ${USERNAME}
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







echo "Installing Redis from IUS..."
yum -q -y install redis30u

echo "Configuring Redis..."

cp -rp /etc/redis.conf /etc/redis.conf.original

sed -i 's/^\# unixsocket \/tmp\/redis.sock/unixsocket \/tmp\/redis.sock/g' /etc/redis.conf
sed -i 's/^# unixsocketperm 700/unixsocketperm 777/g' /etc/redis.conf

sed -i 's/^save 900 1/# save 900 1/g' /etc/redis.conf
sed -i 's/^save 300 10/# save 300 10/g' /etc/redis.conf
sed -i 's/^save 60 10000/# save 60 10000/g' /etc/redis.conf

sed -i '/^\# maxmemory <bytes>/a maxmemory 1GB' /etc/redis.conf
sed -i '/^\# maxmemory-policy volatile-lru/a maxmemory-policy allkeys-lru' /etc/redis.conf


# System / kernel config
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.local

echo "
vm.overcommit_memory = 1
net.core.somaxconn = 1024
" >> /etc/sysctl.conf
sysctl -p >/dev/null 2>&1


echo "redis soft nofile 16384" >> /etc/security/limits.conf
echo "redis hard nofile 16384" >> /etc/security/limits.conf

# Cleanup script 
HOMEDIR=$(getent passwd $USERNAME | cut -d':' -f6)
cd $HOMEDIR
git clone https://github.com/samm-git/cm_redis_tools.git
cd cm_redis_tools
git submodule update --init --recursive

# Create the cron job, and the main Magento Cron while we're here
echo "## Redis cleanup job
33 2 * * * /usr/bin/php $HOMEDIR/cm_redis_tools/rediscli.php -s 127.0.0.1 -p 6379 -d 0,1,2

## Main Magento cron job
*/5 * * * * /bin/bash $HOMEDIR/httpdocs/cron.sh" >> /tmp/rediscron
crontab -l -u $USERNAME | cat - /tmp/rediscron | crontab -u $USERNAME -



if [[ $DBSERVER == 1 ]]; then

### Percona 5.6 setup

PREPDIRCHECK=`ls /home/rack/ | grep magentodbsetup`
if [[ -z "$PREPDIRCHECK" ]]
then
  PREPDIRREUSE="0"
  PREPDIR="/home/rack/magentodbsetup-`date +%Y%m%d`_`/bin/date +%H%M`"
  echo -e "\nCreating prep directory.\nOur working directory will be ${PREPDIR}."
  mkdir $PREPDIR
else
  PREPDIRREUSE="1"
  PREPDIR="/home/rack/${PREPDIRCHECK}"
  echo -e "\nPrevious prep directory detected.\nReusing ${PREPDIR}."
fi

if [[ -f /etc/my.cnf ]] && [[ -f ${PREPDIR}/my.cnf.new ]]
then
  MY1=`md5sum /etc/my.cnf | awk '{print $1}'`
  MY2=`md5sum ${PREPDIR}/my.cnf.new | awk '{print $1}'`
  if [[ "$MY1" != "$MY2" ]]
  then
    MYSQLRECONFIG=1
    NEEDSSECUREINSTALL=0
  fi
else
  NEEDSSECUREINSTALL=1
  echo "[mysqld]

## General
datadir                              = /var/lib/mysql
socket                               = /var/lib/mysql/mysql.sock
tmpdir                               = /dev/shm

## Cache
table-definition-cache               = 4096
table-open-cache                     = 4096
query-cache-size                     = 64M
query-cache-type                     = 1
query-cache-limit                    = 2M


join-buffer-size                    = 2M
read-buffer-size                    = 2M
read-rnd-buffer-size                = 8M
sort-buffer-size                    = 2M

## Temp Tables
max-heap-table-size                 = 96M
tmp-table-size                      = 96M

## Networking
#interactive-timeout                 = 3600
max-connections                      = 500
max-user-connections                 = 400

max-connect-errors                   = 1000000
max-allowed-packet                   = 256M
slave-net-timeout                    = 60
skip-name-resolve
wait-timeout                         = 600

## MyISAM
key-buffer-size                      = 32M
#myisam-recover                      = FORCE,BACKUP
myisam-sort-buffer-size              = 256M

## InnoDB
#innodb-autoinc-lock-mode            = 2
innodb-buffer-pool-size              = ${INNODBMEM}G
#innodb-file-format                  = Barracuda
innodb-file-per-table                = 1
innodb-log-file-size                 = 200M

#innodb-flush-method                 = O_DIRECT
#innodb-large-prefix                 = 0
#innodb-lru-scan-depth               = 1000
#innodb-io-capacity                  = 1000
innodb-purge-threads                 = 4
innodb-thread-concurrency            = 32
innodb_lock_wait_timeout             = 300

## Replication and PITR
#auto-increment-increment            = 2
#auto-increment-offset               = 1
#binlog-format                       = ROW
#expire-logs-days                     = 5
#log-bin                             = /var/log/mysql/bin-log
#log-slave-updates                   = 1
#max-binlog-size                      = 128M
#read-only                           = 1
#relay-log                            = /var/log/mysql/relay-log
#relay-log-space-limit                = 16G
#server-id                            = 1
#slave-compressed-protocol           = 1
#slave-sql-verify-checksum           = 1
#sync-binlog                         = 1
#sync-master-info                    = 1
#sync-relay-log                      = 1
#sync-relay-log-info                 = 1

## Logging
log-output                           = FILE
log-slow-admin-statements
log-slow-slave-statements
#log-warnings                        = 0
long-query-time                      = 4
slow-query-log                       = 1
slow-query-log-file                  = /var/lib/mysqllogs/slow-log

## SSL
#ssl-ca                              = /etc/mysql-ssl/ca-cert.pem
#ssl-cert                            = /etc/mysql-ssl/server-cert.pem
#ssl-key                             = /etc/mysql-ssl/server-key.pem

[mysqld_safe]
log-error                            = /var/log/mysqld.log
#malloc-lib                          = /usr/lib64/libjemalloc.so.1
open-files-limit                     = 65535

[mysql]
no-auto-rehash" > /etc/my.cnf
fi

INNODBLOG=`cat /etc/my.cnf | egrep ^innodb_log_file_size | cut -d= -f2 | tr -d [A-Z][a-z]`
INNODBBUFFER=`cat /etc/my.cnf | egrep ^innodb_buffer_pool_size | cut -d= -f2 | tr -d [A-Z][a-z]`
INNODBMAXPACKET=`cat /etc/my.cnf | egrep ^max_allowed_packet | cut -d= -f2 | tr -d [A-Z][a-z]`

if [[ $PREPDIRREUSE == "0" ]] || [[ $MYSQLRECONFIG == "1" ]]
then
  echo -e "\nUpdating my.cnf."
  wget -q -P $PREPDIR 'https://raw.github.com/abg/upgrade-my.cnf/master/rsdba/upgrade_mysql_config.py'
  cp -a /etc/my.cnf ${PREPDIR}/my.cnf.old
  /usr/bin/python ${PREPDIR}/upgrade_mysql_config.py -l error --config ${PREPDIR}/my.cnf.old --target 5.5 > ${PREPDIR}/my.cnf.new 2>&1
  if [[ -z ${INNODBLOG} ]] || [[ ${INNODBLOG} -lt 100 ]]
  then
    sed -i 's/^innodb_log_file_size/\#innodb_log_file_size/g' ${PREPDIR}/my.cnf.new
    sed -i '/^\[mysqld\]/ s:$:\ninnodb_log_file_size=200M:' ${PREPDIR}/my.cnf.new
  fi
  if [[ -z ${INNODBBUFFER} ]] || [[ ${INNODBBUFFER} -lt 2048 ]]
  then
    sed -i 's/^innodb_buffer_pool_size/\#innodb_buffer_pool_size/g' ${PREPDIR}/my.cnf.new
    sed -i '/^\[mysqld\]/ s:$:\ninnodb_buffer_pool_size=2048M:' ${PREPDIR}/my.cnf.new
  fi
  if [[ -z ${INNODBMAXPACKET} ]] || [[ ${INNODBMAXPACKET} -lt 32 ]]
  then
    sed -i 's/^max_allowed_packet/\#max_allowed_packet/g' ${PREPDIR}/my.cnf.new
    sed -i '/^\[mysqld\]/ s:$:\nmax_allowed_packet=32M:' ${PREPDIR}/my.cnf.new
  fi
  cp -af ${PREPDIR}/my.cnf.new /etc/my.cnf
  echo -e "\nDone."
else
  echo -e "\nmy.cnf already updated.\nContinuing..."
fi


MYSQLVERSION=`mysqladmin version 2>/dev/null | grep Server | awk '{print $3}'`
MYSQLRPM=`rpm -qa | grep mysql.*-server`
# If MySQL is installed but it isn't 5.5 or 5.6MYSQLRPM=`rpm -qa | grep mysql.*-server
if [[ ! -z $MYSQLRPM ]] && grep -v mysql5[56]-server <<< $MYSQLRPM; then
  echo -e "\nUpdating MySQL ${MYSQLVERSION} to latest 5.5."
  yum -q -y install yum-plugin-replace
  yum -q -y replace mysql-server --replace-with mysql55-server
  rm -f /var/lib/mysql/ib_logfile*
  /etc/init.d/mysqld start
  /usr/bin/mysql_upgrade
  /etc/init.d/mysqld restart
  chkconfig mysqld on
  echo -e "\nDone."
fi

echo -e "Installing Percona 5.6."
yum -q -y install http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm
/etc/init.d/mysqld stop 2>/dev/null
rpm -e --nodeps mysql55 mysql55-libs mysql55-server 2>/dev/null
yum -q -y install Percona-Server-server-56 Percona-Server-client-56 Percona-Server-shared-56
cp -af ${PREPDIR}/my.cnf.new /etc/my.cnf
mkdir /var/lib/mysqltmp
mkdir /var/lib/mysqllogs
chmod 1770 /var/lib/mysqltmp
chown mysql:mysql /var/lib/mysqltmp
chown mysql:mysql /var/lib/mysqllogs
chkconfig mysql on
/etc/init.d/mysql start
/usr/bin/mysql_upgrade
mysql -e "CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME 'libfnv1a_udf.so'"
mysql -e "CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME 'libfnv_udf.so'"
mysql -e "CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME 'libmurmur_udf.so'"

echo -e "Securing the MySQL install..."
if [[ ${NEEDSSECUREINSTALL} == 1 ]]
then
  MYSQLROOTPASS=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n1`
  mysql -uroot -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
  mysql -uroot -e "DELETE FROM mysql.user WHERE User=''"
  mysql -uroot -e "DROP DATABASE test"
  mysql -uroot -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
  mysql -uroot -e "UPDATE mysql.user SET Password=PASSWORD('${MYSQLROOTPASS}') WHERE User='root'"

  echo "[client]
user=root
password=${MYSQLROOTPASS}" > /root/.my.cnf
  else
    echo -ne "not required."
    MYSQLROOTPASS=$(grep root /root/.my.cnf | cut -d"=" -f2)
fi

/etc/init.d/mysql restart

if [[ ! -z ${DBNAME} ]]
then
  MYSQLUSERPASS=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n1`
  echo -ne "Creating database and user..."
  mysql -uroot -e "CREATE DATABASE \`${DBNAME}\`"
  mysql -uroot -e "GRANT ALL PRIVILEGES ON \`${DBNAME}\`.* to \`${USERNAME}\`@'localhost' IDENTIFIED BY '${MYSQLUSERPASS}'"
fi



## Backups

if [[ ENVIRONMENT == "DEDICATED" ]]; then
  yum -y -q install rs-holland-backup
  echo -e "\n\nHolland MySQL backup installed - ensure Rackspace MySQL backups are configured."
else
  yum -y -q install holland-mysqldump
  # Holland backup config
  echo "
## Default Backup-Set
##
## Backs up all MySQL databases in a one-file-per-database fashion using
## lightweight in-line compression and engine auto-detection. This backup-set
## is designed to provide reliable backups "out of the box", however it is 
## generally advisable to create additional custom backup-sets to suit
## one's specific needs.
##
## For more inforamtion about backup-sets, please consult the online Holland
## documentation. Fully-commented example backup-sets are also provided, by
## default, in /etc/holland/backupsets/examples.
[holland:backup]
plugin = mysqldump
backups-to-keep = 7
auto-purge-failures = yes
purge-policy = after-backup
estimated-size-factor = 0.3
# This section defines the configuration options specific to the backup
# plugin. In other words, the name of this section should match the name
# of the plugin defined above.
[mysqldump]
file-per-database = yes
#lock-method = auto-detect
#databases = "*"
#exclude-databases =
#tables = "*"
#exclude-tables = "foo.bar"
#stop-slave = no
#bin-log-position = no
# The following section is for compression. The default, unless the
# mysqldump provider has been modified, is to use inline fast gzip
# compression (which is identical to the commented section below).
#[compression]
#method = gzip
#inline = yes
#level = 1
#[mysql:client]
#defaults-extra-file = /root/.my.cnf
" >> /etc/holland/backupsets/default.conf


echo "#! /bin/bash
holland bk" >> /etc/cron.daily/holland
chmod +x /etc/cron.daily/holland



fi






# END if DBSERVER=1
fi









## Service config
for service in php-fpm httpd redis memcached mysql; do
   chkconfig $service on
   service $service restart
done

## iptables for Cloud servers
if [[ $ENVIRONMENT == "CLOUD" ]]; then
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT
    service iptables save
fi



## INFORMATION OUTPUT

echo "



Setup complete. 

This server IP: $(curl -4 icanhazip.com --max-time 3)
SSH Username  : $USERNAME
SSH Password  : $USERPASS
Home Directory: /var/www/vhosts/$DOMAINNAME/
Web doc root  : /var/www/vhosts/$DOMAINNAME/httpdocs/

" 
if [[ ! -z ${DBNAME} ]]; then
echo "
Credentials for Magento local.xml:
MySQL Username: $USERNAME (@localhost)
MySQL Password: $MYSQLUSERPASS
MySQL DB name : $DBNAME
"
else 
   echo "MySQL Root password: ${MYSQLROOTPASS}"
fi

echo "
Redis is available on 127.0.0.1:6379 and /tmp/redis.sock
Memcached is available on 127.0.0.1:11211
"
