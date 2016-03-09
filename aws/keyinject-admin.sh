#!/bin/bash

# The following tags are required:
#   rackuuid - all resources related to the deployment should have the same tag
#              (eg. example.com-20160301)

# The following IAM roles are required:
#   AmazonS3FullAccess
#   AmazonEC2ReadOnlyAccess

if [ ! -d `getent passwd magento | cut -d: -f6`/.ssh/ ];
then
  mkdir `getent passwd magento | cut -d: -f6`/.ssh/
  chown magento:magento `getent passwd magento | cut -d: -f6`/.ssh/
fi

region=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone/ | sed '$ s/.$//'`
uuid=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
keybucket=`/bin/aws ec2 describe-tags --region ${region} --filters "Name=resource-id,Values=${uuid}" "Name=key,Values=rackuuid" --query 'Tags[*].Value[]' --output text`
bucketexist=`/bin/aws s3 ls | grep -c "${keybucket}"`

if [ ${bucketexist} != "1" ];
then
  if [ ! -f `getent passwd magento | cut -d: -f6`/.ssh/magento-admin ];
  then
    ssh-keygen -t rsa -C magento-admin -b 4096 -f `getent passwd magento | cut -d: -f6`/.ssh/magento-admin -q -N ""
    chown magento:magento `getent passwd magento | cut -d: -f6`/.ssh/magento-admin*
    cp -av `getent passwd magento | cut -d: -f6`/.ssh/magento-admin `getent passwd magento | cut -d: -f6`/.ssh/id_rsa
  fi
  /bin/aws s3 mb s3://${keybucket}-lsynckey/
  /bin/aws s3api put-bucket-tagging --bucket ${keybucket}-lsynckey --tagging "TagSet=[{Key=rackuuid,Value=${keybucket}}]"
  /bin/aws s3 cp --sse AES256 "`getent passwd magento | cut -d: -f6`/.ssh/" s3://${keybucket}-lsynckey/ --recursive --include "magento-admin*"
else
  /bin/aws s3 cp s3://${keybucket}-lsynckey/magento-admin `getent passwd magento | cut -d: -f6`/.ssh/
  chmod 600 `getent passwd magento | cut -d: -f6`/.ssh/magento-admin
  chown magento:magento `getent passwd magento | cut -d: -f6`/.ssh/magento-admin
  cp -av `getent passwd magento | cut -d: -f6`/.ssh/magento-admin `getent passwd magento | cut -d: -f6`/.ssh/id_rsa
fi

if [ ! -f /opt/rackspace/lsyncd-elbpoll.sh ]
then
  mkdir /opt/rackspace
  curl -so /opt/rackspace/lsyncd-elbpoll.sh https://raw.githubusercontent.com/whyneus/magneto-ponies/master/aws/lsyncd-elbpoll.sh
fi

if [ ! -f /etc/cron.d/lsyncd ]
then
  echo "*/5 * * * * root /bin/bash /opt/rackspace/lsyncd-elbpoll.sh" >> /etc/cron.d/lsyncd
fi
