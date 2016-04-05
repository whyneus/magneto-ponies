##### Usage
* Run keyinject-admin.sh on the admin node as root on initial start up.
* Run keyinject-web.sh on each web node as root on initial start up.

##### Files
###### keyinject-admin.sh
* Execute on the admin node to create a keypair and send to S3.
* This script executes media-setup.sh.
* This script installs lsyncd-elbpoll.sh.
* If keypair on S3 already exists, downloads the private key.
* Keypair is applied to user "magento".

###### keyinject-web.sh
* Execute on the web heads to pull down the public key from S3.
* Public key is installed for user "magento".
* Checks the number of files in local media/ against the number in S3 media bucket and creates rs-healthc.php once the number of local files is within 20 files of S3 bucket.

###### lsyncd-elbpoll.sh
* To be run as a cronjob on the admin node after keyinject tasks have run.
* Sets up lsyncd.
* Reconfigures lsyncd if web heads behind ELB change.

###### media-setup.sh
* Execute on the admin node to create S3 bucket to house media/ content.
* If S3 bucket already exists, copy all content to load disk.
* Creates S3 bucket for media/ storage or pulls down all files if bucket already exists.
* Configures lsyncd to sync changes made in media/ directory to S3 bucket.
