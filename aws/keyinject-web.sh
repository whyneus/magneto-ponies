#!/bin/bash

# The following tags are required:
#   rackuuid - all resources related to the deployment should have the same tag

# The following IAM roles are required:
#   AmazonS3ReadOnlyAccess
#   AmazonEC2ReadOnlyAccess

if [ ! -d ~magento/.ssh/ ];
then
  mkdir ~magento/.ssh/
  chown magento:magento ~magento/.ssh/
fi

region=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone/ | sed '$ s/.$//'`
uuid=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
keybucket=`/usr/local/bin/aws ec2 describe-tags --region ${region} --filters "Name=resource-id,Values=${uuid}" "Name=key,Values=rackuuid" --query 'Tags[*].Value[]' --output text`

while [ -z ${bucketexist} ]
do
  bucketexist=`/usr/local/bin/aws s3 ls | grep "${keybucket}\-lsynckey"`
  sleep 5
done

if [ ! -z ${keybucket} ]
then
  /usr/local/bin/aws s3 cp s3://${keybucket}-lsynckey/magento-admin.pub `getent passwd magento | cut -d: -f6`/.ssh/
  chmod 600 ~magento/.ssh/magento-admin
  chown magento:magento ~magento/.ssh/magento-admin.pub
fi
