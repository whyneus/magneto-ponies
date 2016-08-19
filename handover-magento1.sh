#! /bin/bash 
# To be sourced from single-server-stack.sh.
# Provides handover steps. 

echo "



Hello,

We have prepared and optimised your solution, ready for you to upload your Magento based website. 


 
This server IP: $(curl -s -4 icanhazip.com --max-time 3)
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

Modify your app/etc/local.xml file with the Database details above. For example: 
"


if [[ ! -z ${DBNAME} ]]; then
    echo "
           <default_setup>
                <connection>
                    <host><![CDATA[localhost]]></host>
                    <username><![CDATA[$USERNAME]]></username>
                    <password><![CDATA[$MYSQLUSERPASS]]></password>
                    <dbname><![CDATA[$DBNAME]]></dbname>
                    <initStatements><![CDATA[SET NAMES utf8]]></initStatements>
                    <model><![CDATA[mysql4]]></model>
                    <type><![CDATA[pdo_mysql]]></type>
                    <pdoType><![CDATA[]]></pdoType>
                    <active>1</active>
                    <persistent>1</persistent>
                </connection>
            </default_setup>
"
else
  echo "
           <default_setup>
                <connection>
                    <host><![CDATA[DB-SERVER-HOST]]></host>
                    <username><![CDATA[DB-USERNAME]]></username>
                    <password><![CDATA[DB-PASSWORD]]></password>
                    <dbname><![CDATA[DB-NAME]]></dbname>
                    <initStatements><![CDATA[SET NAMES utf8]]></initStatements>
                    <model><![CDATA[mysql4]]></model>
                    <type><![CDATA[pdo_mysql]]></type>
                    <pdoType><![CDATA[]]></pdoType>
                    <active>1</active>
                    <persistent>1</persistent>
                </connection>
            </default_setup>

Replace the host, username, password, dbname values as appropriate. 
"
fi 

echo "

4. Cache configuration

We recommend using Redis for Magento cache storage, and this is on the Web server for zero latency performance. 
This step is essential for performance.  

Paste the following into your app/etc/local.xml, before the </global> closing tag:

        <cache>
            <backend>Cm_Cache_Backend_Redis</backend>
            <backend_options>
                <server>/var/run/redis/redis.sock</server>
    	        <port>6379</port>
                <persistent></persistent> 
                <database>1</database> 
                <password></password> 
                <force_standalone>0</force_standalone>  
                <connect_retries>1</connect_retries>    
                <read_timeout>10</read_timeout>         
                <automatic_cleaning_factor>0</automatic_cleaning_factor>
                <compress_data>0</compress_data> 
                <compress_tags>0</compress_tags>  
                <compress_threshold>20480</compress_threshold> 
                <compression_lib>gzip</compression_lib>
                <use_lua>0</use_lua> 
             </backend_options>
        </cache>

        <!-- Magento Enterprise Edition only -->
        <full_page_cache>
            <backend>Cm_Cache_Backend_Redis</backend>
            <backend_options>
                <server>/var/run/redis/redis.sock</server>
    	        <port>6379</port>
                <persistent></persistent> 
                <database>2</database> 
                <password></password> 
                <force_standalone>0</force_standalone>  
                <connect_retries>1</connect_retries>    
                <read_timeout>10</read_timeout>         
                <automatic_cleaning_factor>0</automatic_cleaning_factor>
                <compress_data>0</compress_data> 
                <compress_tags>0</compress_tags>  
                <compress_threshold>20480</compress_threshold> 
                <compression_lib>gzip</compression_lib>
                <use_lua>0</use_lua> 
             </backend_options>
        </full_page_cache>



5. Sessions configuration

We recommend using Memcache for Magento session storage. In your local.xml, replace the existing '<session_save>...' line(s) with:

	<session_save><![CDATA[memcache]]></session_save>
	<session_save_path><![CDATA[tcp://127.0.0.1:11211?persistent=0&weight=2&timeout=10&retry_interval=10]]></session_save_path>



6. Additional local.xml configuration (optional)

If you're using a load balancer, CDN, or any other reverse proxy, you may wish to add the following config, again before the </global> closing tag:

        <remote_addr_headers>
            <header1>HTTP_CF_CONNECTING_IP</header1>    <!-- CloudFlare example -->
            <header2>HTTP_X_FORWARDED_FOR</header2>
        </remote_addr_headers>

We also recommend changing your Magento admin path to something unique: change the value within <adminhtml><args><frontName> in your local.xml. 


7. HTTPS configuration.  

We have configured the web server for HTTPS, using the default server certificate for now.

In order for us to fully manage the Certificate installation and renewal, we recommend that you purchase a certificate via this portal under Network > SSL Certificates. Or, if you have a certificate already, please attach the key, certificate, and CA cert to this ticket and we can set it up for you.





"
