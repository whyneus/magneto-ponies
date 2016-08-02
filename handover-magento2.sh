#! /bin/bash 
# To be sourced from single-server-stack.sh.
# Provides handover steps and config for Magento 2



echo "



Hello,

We have prepared and optimised your solution, ready for you to upload your Magento2 website. 

The installed stack includes:
- HTTP service $WEBSERVER
- Varnish for Magento Full Page Cache
- Redis for backend cache
- PHP 7 (with Zend OPcache) 
- Composer
 
This server IP: $(curl -s -4 icanhazip.com --max-time 3)
SSH Username  : $USERNAME
SSH Password  : $USERPASS
Home Directory: $(getent passwd $USERNAME | cut -d':' -f6)
Web doc root  : $DOCROOT/pub
" 
if [[ ! -z ${DBNAME} ]]; then
echo "
Credentials for Magento app/etc/env.php:
MySQL Username: $USERNAME (@localhost)
MySQL Password: $MYSQLUSERPASS
MySQL DB name : $DBNAME
"
fi

echo "
Here are the steps for you to deploy your site: 


1. Code upload

Use the SSH credentials above to upload your code and content, via SFTP, into to the ~/httpdocs directory. 
You may need to open port 22 in your firewall to allow this connection, under Network > Firewall Manager. 

2. Database import

There are a few ways to do this, but we recommend using the MySQL workbench or similar tools which allow remote connections via SSH tunnel.
With MySQL Workbench, choose 'TCP/IP over SSH' when creating a connection. Use the SSH credentials above for the SSH tunnel, then and MySQL credentials as above.


3. Magento Database configuration

Modify your app/etc/env.php file with the Database details above. For example: 
"

if [[ ! -z ${DBNAME} ]]; then
    echo "
'db' => array(
	'table_prefix' => '',
	'connection' => array(
		'default' => array(
			'host' => 'localhost',
			'dbname' => '$DBNAME',
			'username' => '$USERNAME',
			'password' => '$MYSQLUSERPASS',
			'active' => '1',
		),
	),
),
"
else
  echo "
'db' => array(
        'table_prefix' => '',
        'connection' => array(
                'default' => array(
                        'host' => 'DB-HOST',
                        'dbname' => 'DB-NAME',
                        'username' => 'DB_USERNAME',
                        'password' => 'DB_PASSWORD',
                        'active' => '1',
                ),
        ),
),

Replace the host, username, password, dbname values as appropriate. 
"
fi 

echo "

4. Full Page Cache (Varnish) configuration

For Full Page Cache in Magento 2, Varnish has been configured with a Magento VCL, and is listening on port 80. 

For further instructions, please see http://devdocs.magento.com/guides/v2.0/config-guide/varnish/config-varnish-magento.html 




5. Backend Cache (Redis) configuration

We recommend using Redis for Magento backend cache storage, and this is on the Web server for zero latency performance. 
This step is essential for performance.  

Paste the following into your app/etc/env.php :


'cache' =>
array (
  'frontend' =>
  array (
    'default' =>
    array (
      'backend' => 'Cm_Cache_Backend_Redis',
      'backend_options' =>
      array (
        'server' => '/var/run/redis/redis.sock',
        'port' => '6379',
        'password' => '',
        'persistent' => '',
        'database' => '1',
        'force_standalone' => '0',
        'connect_retries' => '1',
        'read_timeout' => '10',
        'automatic_cleaning_factor' => '0',
        'compress_data' => '0',
        'compress_tags' => '0',
        'compress_threshold' => '20480',
        'compression_lib' => 'gzip',
      ),
    ),
  ),
),




5. HTTPS configuration.  

We have configured the web server for HTTPS, using the default server certificate for now.

In order for us to fully manage the Certificate installation and renewal, we recommend that you purchase a certificate via this portal under Network > SSL Certificates. Or, if you have a certificate already, please attach the key, certificate, and CA cert to this ticket and we can set it up for you.





"
