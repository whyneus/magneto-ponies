#!/bin/bash

# The following IAM roles are required:
#   AmazonS3ReadOnlyAccess

if [ ! -d ~magento/.ssh/ ];
then
  mkdir ~magento/.ssh/
  chown magento:magento ~magento/.ssh/
fi

while [ -z ${keybucket} ]
do
  keybucket=`/usr/local/bin/aws s3 ls | grep lsynckey\\-rax\\- | awk '{print $3}'`
  sleep 5
done

if [ ! -z ${keybucket} ]
then
  /usr/local/bin/aws s3 cp s3://${keybucket}/magento-admin.pub `getent passwd magento | cut -d: -f6`/.ssh/
  chmod 600 ~magento/.ssh/magento-admin
  chown magento:magento ~magento/.ssh/magento-admin.pub
fi
