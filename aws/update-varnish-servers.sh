#! /bin/bash
# To update Magento's list of Varnish Servers
# Based on list in /tmp/awsec2webips which will be populated separately.


VARNISHADMPORT=6082

DOCROOT="$(getent passwd magento | cut -d: -f6)/httpdocs"
N98MAGERUN="/usr/local/bin/n98-magerun.phar --root-dir=$DOCROOT "


PHOENIX=$($N98MAGERUN dev:module:list --status active | grep Phoenix_VarnishCache)
NEXCESS=$($N98MAGERUN dev:module:list --status active | grep Nexcessnet_Turpentine)

# Incomment for custom implementations
# $CUSTOMCONFIGPATH="module/config/path"

# Use list in /tmp/serverlist for now
if [ ! -f /tmp/awsvarniships ];
then
  touch /tmp/awsvarniships
fi

webipchange=`diff /tmp/awsec2webips /tmp/awsvarniships`
if [[ ! -z ${webipchange} ]];
then

  if [[ $PHOENIX ]]
    # Phoenix needs a semicolon-separated list
    CONFIGVALUE=$(cat /tmp/awsec2webips)
    $N98MAGERUN config:set varnishcache/general/servers $CONFIGVALUE
  fi
  
  if [[ $TURPENTINE ]]
    # Turpentine uses a newline-separated list with ports a semicolon-separated list
    CONFIGVALUE=$(cat /tmp/awsec2webips)
    $N98MAGERUN config:set turpentine_varnish/servers/server_list $CONFIGVALUE
  fi
  
  if [[ $CUSTOMCONFIGPATH ]]
    CONFIGVALUE=$(cat /tmp/awsec2webips) # modify as appropriate
    $N98MAGERUN config:set $CUSTOMCONFIGPATH $CONFIGVALUE
  fi 

  # Clear the config cache
  n98-magerun.phar --root-dir=$DOCROOT cache:clean config
  
  # Copy the current list for comparison next time
  /bin/cp -f /tmp/awsec2webips /tmp/awsvarniships
fi

# work in progress.....
