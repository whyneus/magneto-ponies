#!/bin/bash

# The following IAM roles are required:
#   AmazonS3FullAccess
#   AmazonEC2ReadOnlyAccess

if [ ! -d ~magento/.ssh/ ];
then
  mkdir ~magento/.ssh/
  chown magento:magento ~magento/.ssh/
fi

keybucket=lsynckey-`/usr/local/bin/aws ec2 describe-tags --region eu-west-1 --filters "Name=resource-id,Values=`curl -s http://169.254.169.254/latest/meta-data/instance-id`" "Name=key,Values=rackuuid" --query 'Tags[*].Value[]' --output text`
if [ ${bucketexist} -eq 0 ];
then
  if [ ! -f ~magento/.ssh/magento-admin ];
  then
    ssh-keygen -t rsa -C magento-admin -b 4096 -f ~magento/.ssh/magento-admin -q -N ""
    chown magento:magento ~magento/.ssh/magento-admin*
  fi
  /usr/local/bin/aws s3 mb s3://${keybucket}/
  /usr/local/bin/aws s3 cp --sse AES256 "`getent passwd magento | cut -d: -f6`/.ssh/" s3://${keybucket}/ --recursive --include "magento-admin*"
else
  /usr/local/bin/aws s3 cp s3://${keybucket}/magento-admin `getent passwd magento | cut -d: -f6`/.ssh/
  chmod 600 ~magento/.ssh/magento-admin
  chown magento:magento ~magento/.ssh/magento-admin
fi
