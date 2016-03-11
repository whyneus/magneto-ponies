###### keyinject-admin.sh
* Execute on the admin node to create a keypair and send to S3.
* If keypair on S3 already exists, downloads the private key.
* Keypair is applied to user "magento".

###### keyinject-web.sh
* Execute on the web heads to pull down the public key from S3.
* Public key is installed for user "magento".

###### lsyncd-elbpoll.sh
* To be run as a cronjob on the admin server after keyinject tasks have run.
* Sets up lsyncd.
* Reconfigures lsyncd if web heads behind ELB change.

###### media-setup.sh
* Execute on the admin node to create S3 bucket to house media/ content.
* If S3 bucket already exists, copy all content to load disk.
