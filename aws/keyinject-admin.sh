#!/bin/bash

# The following tags are required:
#   rackuuid - all resources related to the deployment should have the same tag

# The following IAM roles are required:
#   AmazonS3FullAccess
#   AmazonEC2ReadOnlyAccess

if [ ! -d ~magento/.ssh/ ];
then
  mkdir ~magento/.ssh/
  chown magento:magento ~magento/.ssh/
fi

region=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone/ | sed '$ s/.$//'`
uuid=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
keybucket=`/usr/local/bin/aws ec2 describe-tags --region ${region} --filters "Name=resource-id,Values=${uuid}" "Name=key,Values=rackuuid" --query 'Tags[*].Value[]' --output text`
bucketexist=`/usr/local/bin/aws s3 ls | grep -c "${keybucket}"`

if [ ${bucketexist} != "1" ];
then
  if [ ! -f ~magento/.ssh/magento-admin ];
  then
    ssh-keygen -t rsa -C magento-admin -b 4096 -f ~magento/.ssh/magento-admin -q -N ""
    chown magento:magento ~magento/.ssh/magento-admin*
  fi
  /usr/local/bin/aws s3 mb s3://${keybucket}-lsynckey/
  /usr/local/bin/aws s3api put-bucket-tagging --bucket ${keybucket}-lsynckey --tagging "TagSet=[{Key=rackuuid,Value=${keybucket}}]"
  /usr/local/bin/aws s3 cp --sse AES256 "`getent passwd magento | cut -d: -f6`/.ssh/" s3://${keybucket}-lsynckey/ --recursive --include "magento-admin*"
else
  /usr/local/bin/aws s3 cp s3://${keybucket}-lsynckey/magento-admin `getent passwd magento | cut -d: -f6`/.ssh/
  chmod 600 ~magento/.ssh/magento-admin
  chown magento:magento ~magento/.ssh/magento-admin
fi
