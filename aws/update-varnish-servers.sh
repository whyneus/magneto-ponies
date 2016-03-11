#! /bin/bash
# To update Magento's list of Varnish Servers
# Based on list in /tmp/awsec2webips which will be populated separately.


AWSEC2WEBIPs="/tmp/awsec2webips"

# Use list file $AWSEC2WEBIPs
if [ ! -f $AWSEC2WEBIPs ];
then
  touch $AWSEC2WEBIPs
fi

webipchange=`diff $AWSEC2WEBIPs /tmp/varnish-servers`
if [[ -z ${webipchange} ]]; then
  # No change 
  echo "No change. "
  exit 0
fi

DOCROOT="$(getent passwd magento | cut -d: -f6)/httpdocs"
#DOCROOT="/var/www/html/magento"
N98MAGERUN="/usr/local/bin/n98-magerun.phar --root-dir=$DOCROOT "


PHOENIX=$($N98MAGERUN dev:module:list --status active | grep Phoenix_VarnishCache)
TURPENTINE=$($N98MAGERUN dev:module:list --status active | grep Nexcessnet_Turpentine)

# Uncomment for custom implementations
# $CUSTOMCONFIGPATH="module/config/path"


  if [[ $PHOENIX ]]; then
    # Phoenix needs a semicolon-separated list
    DELIMITER=";"
    CONFIGVALUE=$(cat $AWSEC2WEBIPs | sed -e "s/\s/${DELIMITER}/g")
    echo $CONFIGVALUE
    $N98MAGERUN config:set varnishcache/general/servers "$CONFIGVALUE"
  fi
  
  if [[ $TURPENTINE ]]; then
    # Turpentine uses a newline-separated list with ports a semicolon-separated list
    VARNISHADMPORT=6082
    DELIMITER=":${VARNISHADMPORT}\n"
    CONFIGVALUE=$(cat $AWSEC2WEBIPs | sed -e "s/\s/${DELIMITER}/g")
    $N98MAGERUN config:set turpentine_varnish/servers/server_list "$CONFIGVALUE"
  fi
  
  if [[ $CUSTOMCONFIGPATH ]]; then
    DELIMITER=","
    CONFIGVALUE=$(cat $AWSEC2WEBIPs | sed -e "s/\s/{DELIMITER}/g") # modify as appropriate
    $N98MAGERUN config:set $CUSTOMCONFIGPATH $CONFIGVALUE
  fi 

  # Clear the config cache
  n98-magerun.phar --root-dir=$DOCROOT cache:clean config
  
  # Copy the current list for comparison next time
  /bin/cp -f $AWSEC2WEBIPs /tmp/varnish-servers

