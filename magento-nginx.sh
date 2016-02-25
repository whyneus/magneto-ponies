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

if grep -qi "Red Hat" /etc/redhat-release; then
  echo "[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/rhel/6/\$basearch/
gpgcheck=0
enabled=1" > /etc/yum.repos.d/nginx.repo
else echo "[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/6/\$basearch/
gpgcheck=0
enabled=1"  > /etc/yum.repos.d/nginx.repo
fi

yum -y install nginx

# Nginx 'virtualhost'

if [ -e /etc/nginx/conf.d/$DOMAINNAME.conf ]; then
   echo "/etc/nginx/conf.d/$DOMAINNAME.conf already exists - skipping Nginx server{} config."
else
   echo -e "
   
# Redirect to www. 
server {
    listen 80${PORTSUFFIX};
    server_name $DOMAINNAME;
    return 301 \$scheme://www.\$host\$request_uri;
}
   
   ## Separate backends for frontend and "admin" - IN PROGRESS
#   upstream  backend  {
#     server unix:/var/run/php-fpm/${DOMAINNAME}.sock;
#  }
#  upstream  backend-admin  {
#    server unix:/var/run/php-fpm/${DOMAINNAME}-admin.sock;
#  }
#  map  "URL:$request_uri." $fcgi_pass {
#        default                 backend;
#        ~URL:.*admin.*          backend-admin;
# }

server {
 listen 80${PORTSUFFIX};
 server_name www.$DOMAINNAME media.$DOMAINNAME skin.$DOMAINNAME js.$DOMAINNAME;
 root $DOCROOT;
 
 access_log /var/log/nginx/$DOMAINNAME-access.log;
 error_log /var/log/nginx/$DOMAINNAME-error.log;
 
 client_body_buffer_size 8k;
 client_max_body_size 10M;
 client_header_buffer_size 1k;
 large_client_header_buffers 4 16k;
 
 # SSL Termination
 if (\$server_port = 80) { set \$httpss off; }
 if (\$http_x_forwarded_proto = "https") { set \$httpss "on"; }
 
 location / {
 index index.html index.php;
 try_files \$uri \$uri/ @handler;
 expires 30d;
 }
 
 location ~ ^/(app|includes|media/downloadable|pkginfo|report/config.xml|var)/ { deny all; }
 
 location /. { return 404; }
 
 location @handler { rewrite / /index.php; }
 location ~ .php/ { rewrite ^(.*.php)/ $1 last; }
 
 location ~ .php$
 {
 if (\0041-e \$request_filename) { rewrite / /index.php last; }
 expires off;
 fastcgi_pass unix:/var/run/php-fpm/${DOMAINNAME}.sock;
 fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
 fastcgi_param MAGE_RUN_CODE default;
 fastcgi_param MAGE_RUN_TYPE store;
 fastcgi_param HTTPS \$httpss;
 include fastcgi_params;
 fastcgi_buffer_size 32k;
 fastcgi_buffers 512 32k;
 fastcgi_read_timeout 300;
 }
}



" > /etc/nginx/conf.d/$DOMAINNAME.conf
fi 


chkconfig nginx on
/etc/init.d/nginx start
