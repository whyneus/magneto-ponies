#! /bin/bash
# To update Magento's list of Varnish Servers

PHOENIX = $(n98-magerun dev:module:list --status active | grep Phoenix_VarnishCache)
NEXCESS = $(n98-magerun dev:module:list --status active | grep Nexcessnet_Turpentine)

# Use list in /tmp/serverlist for now

# n98-magerun config:get varnishcache/general/servers

# work in progress.....
