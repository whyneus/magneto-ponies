#! /bin/bash
#  Simple logrotate config for Magento servers. 

echo "
/var/www/vhosts/*/httpdocs/var/log/system.log /var/www/vhosts/*/httpdocs/var/log/exception.log  {
    weekly
    rotate 8
    copytruncate
    delaycompress
    notifempty
    missingok
}

# In case Magento is using /tmp as a fallback option
/tmp/magento/var/log/*.log  {
    daily
    rotate 7
    copytruncate
    notifempty
    compress
    missingok
}
" >> /etc/logrotate.d/magento
