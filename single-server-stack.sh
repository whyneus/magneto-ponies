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

MAGENTO2=false


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



echo -ne "\n\nPrimary website domain name (not including \"www\.\"): "
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

echo -ne "\nWebsite document root:\nDefault is /var/www/vhosts/$DOMAINNAME/httpdocs : "
read DOCROOT
if [[ -z ${DOCROOT} ]]
then
  DOCROOT="/var/www/vhosts/$DOMAINNAME/httpdocs"
fi

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

  
if [[ -z ${DOMAINNAME} ]]
then
  echo -e "\nWe need a site to configure PHP-FPM on.\nExiting."
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
  Document Root: $DOCROOT

NB: if PHP is already installed, this script will remove all config and replace with $PHPVERS optimised for Magento.)
"
if [[ $MAGENTO2 == true ]]; then
  echo "  Magento 2: Yes (Varnish will aslo be installed)"
else
  if [[ "$PHPVERS" == "base" ]]; then 
     echo "For EL 7, we will use the long-life base PHP version, which is PHP 5.4."
  fi
fi


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
yum -y remove dovecot >/dev/null 2>&1




# Create user and Document Root. Home directory will be one up from $DOCROOT. 
USERPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n1)
USEREXIST=`id ${USERNAME} 2>&1 >/dev/null`
echo -e "\nCreating user ${USERNAME}..."
if [[ -z ${USEREXIST} ]]
then
  echo -e "\nUser already exists.\nCheck that it has permissions to access to ${DOCROOT}.\nContinuing..."
else
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



# Web server config

if [[ $MAGENTO2 == true ]]; then
  PORTSUFFIX=80
fi

if [[ $WEBSERVER == "nginx" ]]; then
. <(curl -s https://raw.githubusercontent.com/whyneus/magneto-ponies/master/magento-nginx.sh)
else
  # Apache config moved to separate script
  . <(curl -s https://raw.githubusercontent.com/whyneus/magneto-ponies/master/magento-apache.sh)
fi 

# Redis install - separate module
. <(curl -s https://raw.githubusercontent.com/whyneus/magneto-ponies/master/magento-redis.sh)


# All PHP=FPM config moved to separate script
. <(curl -s https://raw.githubusercontent.com/whyneus/magneto-ponies/master/magento-php-fpm.sh)

if [[ $MAGENTO2 == true ]]; then
  echo "Setting up Varnish 4.0 ..."
  . <(curl -s https://raw.githubusercontent.com/whyneus/magneto-ponies/master/magento2-varnish.sh)
  echo "Setting up Comoser ..."
  curl -sS https://getcomposer.org/installer | sudo php -d "allow_url_fopen=1" -- --install-dir=/usr/local/bin --filename=composer
else
  echo "Setting up n98-magerun"
  wget https://files.magerun.net/n98-magerun.phar -O /usr/local/bin/n98-magerun.phar
  chmod +x /usr/local/bin/n98-magerun.phar
  ln -s /usr/local/bin/n98-magerun.phar /usr/local/bin/n98-magerun
fi


# Create the cron job, and the main Magento Cron while we're here
echo "
## Main Magento cron job
*/5 * * * * /bin/bash $HOMEDIR/httpdocs/cron.sh" >> /tmp/magentocron
crontab -l -u $USERNAME | cat - /tmp/magentocron | crontab -u $USERNAME -



if [[ $DBSERVER == 1 ]]; then

### Percona 5.6 setup

MEMORY=`cat /proc/meminfo | grep MemTotal | awk 'OFMT="%.0f" {sum=$2/1024/1024}; END {print sum}'`
if [[ ${MEMORY} -lt 12 ]]
then
  INNODBMEM=`printf "%.0f" $(bc <<< ${MEMORY}*0.75)`G
else
  INNODBMEM=6G
fi
if [[ ${MEMORY} -lt 2 ]]
then
INNODBMEM=256M
fi

PREPDIRCHECK=`ls /home/rack/ | grep magentodbsetup`
if [[ -z "$PREPDIRCHECK" ]]
then
  PREPDIRREUSE="0"
  PREPDIR="/home/rack/magentodbsetup-`date +%Y%m%d`_`/bin/date +%H%M`"
  echo -e "\nCreating prep directory.\nOur working directory will be ${PREPDIR}."
  mkdir -p $PREPDIR
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
fi


echo "[mysqld]

## General
datadir                              = /var/lib/mysql
socket                               = /var/lib/mysql/mysql.sock
tmpdir                               = /dev/shm

performance-schema		= OFF

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
innodb-buffer-pool-size              = ${INNODBMEM}
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

optimizer_switch                     = 'use_index_extensions=off'
transaction_isolation                = 'READ-COMMITTED'

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
no-auto-rehash" > $PREPDIR/my.cnf.new


MYSQLVERSION=`mysqladmin version | grep Server | awk '{print $3}'`
MYSQLRPM=`rpm -qa | egrep 'mysql55-server|mariadb-server-5.5'`
if [[ -z $MYSQLRPM ]]
then
  echo -e "\nUpdating MySQL ${MYSQLVERSION} to latest 5.5."
  yum -q -y install yum-plugin-replace
  yum -q -y replace mysql-server --replace-with mysql55-server
  rm -f /var/lib/mysql/ib_logfile*
  /etc/init.d/mysqld start
  /usr/bin/mysql_upgrade
  /etc/init.d/mysqld restart
  chkconfig mysqld on
  echo -e "\nDone."
else
  echo -e "\n${MYSQLRPM} appears to already be installed.\nContinuing..."
fi

echo -e "Moving to Percona 5.6."

if [[ $MAJORVERS == "6" ]]; then
   /etc/init.d/mysqld stop
   rpm -e --nodeps mysql55 mysql55-libs mysql55-server
fi

if [[ $MAJORVERS == "7" ]]; then
   /bin/systemctl stop mariadb.service
   rpm -e --nodeps mariadb mariadb-server mariadb-libs
fi


yum -y install http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm

yum -y install Percona-Server-server-56 Percona-Server-client-56 Percona-Server-shared-56

if [[ -f /etc/my.cnf ]]; then 
  mv /etc/my.cnf ${PREPDIR}/my.cnf.backup
fi
cp -af ${PREPDIR}/my.cnf.new /etc/my.cnf
mkdir /var/lib/mysqltmp
mkdir /var/lib/mysqllogs
chmod 1770 /var/lib/mysqltmp
chown mysql:mysql /var/lib/mysqltmp
chown mysql:mysql /var/lib/mysqllogs

if [[ $MAJORVERS == "6" ]]; then
   /etc/init.d/mysql start
   chkconfig mysql on
fi

if [[ $MAJORVERS == "7" ]]; then
   /bin/systemctl start mysql.service
   /bin/systemctl enable  mysql.service

fi


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
 
  service mysql restart
  
  echo "[client]
user=root
password=${MYSQLROOTPASS}" > /root/.my.cnf
  else
    echo -ne "not required."
    MYSQLROOTPASS=$(grep root /root/.my.cnf | cut -d"=" -f2)
fi


if [[ ! -z ${DBNAME} ]]
then
  MYSQLUSERPASS=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n1`
  echo -ne "Creating database and user..."
  mysql -uroot -e "CREATE DATABASE \`${DBNAME}\`"
  mysql -uroot -e "GRANT ALL PRIVILEGES ON \`${DBNAME}\`.* to \`${USERNAME}\`@'localhost' IDENTIFIED BY '${MYSQLUSERPASS}'"
  mysql -uroot -e "GRANT ALL PRIVILEGES ON \`${DBNAME}\`.* to \`${USERNAME}\`@'127.0.0.1' IDENTIFIED BY '${MYSQLUSERPASS}'"
  mysql -uroot -e "GRANT ALL PRIVILEGES ON \`${DBNAME}\`.* to \`${USERNAME}\`@'::1'       IDENTIFIED BY '${MYSQLUSERPASS}'"
fi



## Backups

if [[ $ENVIRONMENT == "DEDICATED" ]]; then
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
" > /etc/holland/backupsets/default.conf


echo "#! /bin/bash
holland bk" >> /etc/cron.daily/holland
chmod +x /etc/cron.daily/holland



fi






# END if DBSERVER=1
fi





## Logrotate config
source <(curl -s https://raw.githubusercontent.com/whyneus/magneto-ponies/master/magento-logrotate.sh)




## Memcached config, for good measure

if [[ $MAJORVERS == "6" ]]; then
   /etc/init.d/memcached restart
   chkconfig memcached on
fi

if [[ $MAJORVERS == "7" ]]; then
   /bin/systemctl start  memcached.service
   /bin/systemctl enable  memcached.service
fi





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
Home Directory: $(getent passwd $USERNAME | cut -d':' -f6)
Web doc root  : $DOCROOT

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
Redis is available on 127.0.0.1:6379 and /var/run/redis/redis.sock
Memcached is available on 127.0.0.1:11211
"


# HANDOVER details

if [[ $MAGENTO2 == true ]]; then
    source <(curl -s https://raw.githubusercontent.com/whyneus/magneto-ponies/master/handover-magento2.sh)
else 
    source <(curl -s https://raw.githubusercontent.com/whyneus/magneto-ponies/master/handover-magento1.sh)
fi
