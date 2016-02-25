###### keyinject-admin.sh
Execute on the admin node to create a keypair and send to S3.
If keypair on S3 already exists, downloads the private key.
Keypair is applied to user "magento".

###### keyinject-web.sh
Execute on the web heads to pull down the public key from S3.
Public key is installed for user "magento".
