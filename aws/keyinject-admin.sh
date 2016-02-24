#!/bin/bash

# The following IAM roles are required:
#   AmazonS3FullAccess
#   IAMReadOnlyAccess

if [ ! -d ~magento/.ssh/ ];
then
  mkdir ~magento/.ssh/
  chown magento:magento ~magento/.ssh/
fi

keybucket=lsynckey-`/usr/local/bin/aws iam list-account-aliases | grep rax\\- | head -n1 | sed 's/"//g' | sed 's/[[:blank:]]//g'`
bucketexist=`/usr/local/bin/aws s3 ls | grep -c ${keybucket}`
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
