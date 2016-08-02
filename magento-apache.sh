#! /bin/bash
#
# Script to set up Apache for Magento. 
# Compiles mod_fastcgi for use with PHP-FPM. 
#
# Relies on PHP sockets: /var/run/php-fpm/${DOMAINNAME}.sock and /var/run/php-fpm/${DOMAINNAME}-admin.sock
# NB: To separate "admin" FPM pool, change "<Location ~ admin>" to "<Location ~ actualAdminPath>". The admin path should be unique for security. 


## Sanity checks - root on RHEL/CentOS 6 or 7

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

# DocRoot .../pub for Magento2
if [[ MAGENTO2 == true ]]; then 
   MAGE2PUB="/pub"
fi


# Basic package installs 

yum -q -y install httpd mod_ssl



if [[ $MAJORVERS == "6" ]]; then 

sed -i s/^ServerTokens\ OS/ServerTokens\ Prod/g /etc/httpd/conf/httpd.conf


### Apache mod_fastcgi install

HTTPDDEVEL=`rpm -qa | grep -e "httpd.*devel.*"`
echo -e "\nIntalling Apache mod_fastcgi..."
if [[ -z ${HTTPDDEVEL} ]]
then
  yum -q -y install httpd-devel httpd mod_ssl
fi

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
  wget -q -P ${PREPDIR} 'https://github.com/whyneus/magneto-ponies/raw/master/mod_fastcgi-SNAP-0910052141.tar.gz'
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
  echo "LoadModule fastcgi_module /usr/lib64/httpd/modules/mod_fastcgi.so
DirectoryIndex index.php" > /etc/httpd/conf.d/fastcgi.conf
else
  echo -e "\nModule already appears to be installed.\nContinuing..."
fi
echo "# mod_fastcgi in use for PHP-FPM. This file here to prevent 'php' package creating new config." > /etc/httpd/conf.d/php.conf



else 
   echo "ServerTokens Prod" >> /etc/httpd/conf/httpd.conf

   echo "# Apache 2.4 using PHP-FPM. Not using loading mod_php. 
# This file here to prevent 'php' package creating new config.

DirectoryIndex index.php" > /etc/httpd/conf.d/php.conf
fi 

# Add PORTSUFFIX to listen port
sed -i s/^Listen\ 80$/Listen\ 80${PORTSUFFIX}/g /etc/httpd/conf/httpd.conf

HOSTNAME=`hostname`
VHOSTEXISTS=`httpd -S 2>&1 | grep -v ${HOSTNAME} | grep ${DOMAINNAME}`
if [[ -z ${VHOSTEXISTS} ]]
then
  NAMEDBASEDEXISTS=`grep -e ^NameVirt -R /etc/httpd/`
  INCLUDEEXISTS=`grep -e ^Include.*vhosts\.d.*conf -R /etc/httpd/`
  if [[ -z ${NAMEDBASEDEXISTS} ]]
  then
    echo -e "\nNameVirtualHost *:80${PORTSUFFIX}" >> /etc/httpd/conf/httpd.conf
    echo -e "\nNameVirtualHost *:443" >> /etc/httpd/conf/httpd.conf
  fi
  if [[ -z ${INCLUDEEXISTS} ]]
  then
    echo -e "\nInclude vhosts.d/*.conf" >> /etc/httpd/conf/httpd.conf
  fi
fi

if [[ -z ${VHOSTEXISTS} ]]; then

if [[ $MAJORVERS == "6" ]]; then

  mkdir -p /etc/httpd/vhosts.d

  echo "<VirtualHost *:80${PORTSUFFIX}>
  ServerName ${DOMAINNAME}
  ServerAlias www.${DOMAINNAME}
  DocumentRoot ${DOCROOT}${MAGE2PUB}
  SetEnvIf X-Forwarded-Proto https HTTPS=on
  <Directory ${DOCROOT}>
    AllowOverride All
    Options +FollowSymLinks
    # Compress JS and CSS. HTML/PHP will be compressed by PHP. 
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/css text/javascript application/javascript
    </IfModule>
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
    FastCGIExternalServer /dev/shm/${DOMAINNAME}-admin.fcgi -socket /var/run/php-fpm/${DOMAINNAME}-admin.sock -flush -idle-timeout 1800
 	  <Location ~ admin>
      # Override Action for “admin” URLs
      Action php5-fcgi /${DOMAINNAME}-admin.fcgi
    </Location>
    Alias /${DOMAINNAME}-admin.fcgi /dev/shm/${DOMAINNAME}-admin.fcgi
    
  </IfModule>
</VirtualHost>" > /etc/httpd/vhosts.d/${DOMAINNAME}.conf

MYIP=$(curl -s4 icanhazip.com --max-time 3);

echo "<VirtualHost *:443>
  ServerName ${DOMAINNAME}
  ServerAlias www.${DOMAINNAME} $MYIP
  DocumentRoot ${DOCROOT}${MAGE2PUB}

   SSLEngine On
   # Default certificates - swap for real ones when provided
   SSLCertificateFile /etc/pki/tls/certs/localhost.crt
   SSLCertificateKeyFile /etc/pki/tls/private/localhost.key
   # SSLCACertificateFile   /etc/pki/tls/certs/cert.ca
  
  <Directory ${DOCROOT}>
    AllowOverride All
    Options +FollowSymLinks
    # Compress JS and CSS. HTML/PHP will be compressed by PHP. 
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/css text/javascript application/javascript
    </IfModule>
    ExpiresActive On
    ExpiresDefault \"access plus 1 month\"
  </Directory>
  # Allow web fonts across parallel hostnames
  <FilesMatch \"\.(ttf|otf|eot|svg|woff)$\">
      <IfModule mod_headers.c>
      Header set Access-Control-Allow-Origin "*"
      </IfModule>
  </FilesMatch>
  CustomLog /var/log/httpd/${DOMAINNAME}-ssl_access_log combined
  ErrorLog /var/log/httpd/${DOMAINNAME}-ssl_error_log
  <IfModule mod_fastcgi.c>
    AddHandler php5-fcgi .php
    Action php5-fcgi /php5-fcgi
    Alias /php5-fcgi /dev/shm/${DOMAINNAME}.fcgi
    # These only need to be defined once
    # FastCGIExternalServer /dev/shm/${DOMAINNAME}.fcgi -socket /var/run/php-fpm/${DOMAINNAME}.sock -flush -idle-timeout 1800
    # FastCGIExternalServer /dev/shm/${DOMAINNAME}-admin.fcgi -socket /var/run/php-fpm/${DOMAINNAME}-admin.sock -flush -idle-timeout 1800
 	  <Location ~ admin>
      # Override Action for "admin" URLs
      Action php5-fcgi /${DOMAINNAME}-admin.fcgi
    </Location>
    Alias /${DOMAINNAME}-admin.fcgi /dev/shm/${DOMAINNAME}-admin.fcgi
    
  </IfModule>
</VirtualHost>" > /etc/httpd/vhosts.d/${DOMAINNAME}-ssl.conf

chkconfig httpd on
/etc/init.d/httpd restart

fi 

if [[ $MAJORVERS == "7" ]]; then

echo "<Proxy \"unix:/var/run/php-fpm/${DOMAINNAME}.sock|fcgi://php-fpm\">
  ProxySet disablereuse=off
</Proxy>
<Proxy \"unix:/var/run/php-fpm/${DOMAINNAME}-admin.sock|fcgi://php-fpm-admin\">
  ProxySet disablereuse=off
</Proxy>
" >> /etc/httpd/conf.d/fpm-proxy.conf


mkdir -p /etc/httpd/vhosts.d
  echo "<VirtualHost *:80${PORTSUFFIX}>
  ServerName ${DOMAINNAME}
  ServerAlias www.${DOMAINNAME}
  DocumentRoot ${DOCROOT}${MAGE2PUB}
  SetEnvIf X-Forwarded-Proto https HTTPS=on
  <Directory ${DOCROOT}>
    AllowOverride All
    Options +FollowSymLinks
    # Compress JS and CSS. HTML/PHP will be compressed by PHP. 
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/css text/javascript application/javascript
    </IfModule>
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

  <FilesMatch \.php$>
    SetHandler proxy:fcgi://php-fpm
  </FilesMatch>
  <LocationMatch \".*/admin/(.*)\.php$\">
     SetHandler proxy:fcgi://php-fpm-admin
  </LocationMatch>

</VirtualHost>" > /etc/httpd/vhosts.d/${DOMAINNAME}.conf

MYIP=$(curl -s4 icanhazip.com --max-time 3);

echo "<VirtualHost *:443>
  ServerName ${DOMAINNAME}
  ServerAlias www.${DOMAINNAME} $MYIP
  DocumentRoot ${DOCROOT}${MAGE2PUB}

   SSLEngine On
   # Default certificates - swap for real ones when provided
   SSLCertificateFile /etc/pki/tls/certs/localhost.crt
   SSLCertificateKeyFile /etc/pki/tls/private/localhost.key
   # SSLCACertificateFile   /etc/pki/tls/certs/cert.ca
  
  <Directory ${DOCROOT}>
    AllowOverride All
    Options +FollowSymLinks
    # Compress JS and CSS. HTML/PHP will be compressed by PHP. 
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/css text/javascript application/javascript
    </IfModule>
    ExpiresActive On
    ExpiresDefault \"access plus 1 month\"
  </Directory>
  # Allow web fonts across parallel hostnames
  <FilesMatch \"\.(ttf|otf|eot|svg|woff)$\">
      <IfModule mod_headers.c>
      Header set Access-Control-Allow-Origin "*"
      </IfModule>
  </FilesMatch>
  CustomLog /var/log/httpd/${DOMAINNAME}-ssl_access_log combined
  ErrorLog /var/log/httpd/${DOMAINNAME}-ssl_error_log

  <FilesMatch \.php$>
    SetHandler proxy:fcgi://php-fpm
  </FilesMatch>
  <LocationMatch \".*/admin/(.*)\.php$\">
     SetHandler proxy:fcgi://php-fpm-admin
  </LocationMatch>

</VirtualHost>" > /etc/httpd/vhosts.d/${DOMAINNAME}-ssl.conf


/bin/systemctl restart  httpd.service
/bin/systemctl enable  httpd.service

fi 

fi

httpd -S
