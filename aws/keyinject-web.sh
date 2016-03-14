#!/bin/bash

# The following tags are required:
#   rackuuid - all resources related to the deployment should have the same tag
#              (eg. example.com-20160301)

# The following IAM roles are required:
#   AmazonS3ReadOnlyAccess
#   AmazonEC2ReadOnlyAccess

region=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone/ | sed '$ s/.$//'`
uuid=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
keybucket=`/bin/aws ec2 describe-tags --region ${region} --filters "Name=resource-id,Values=${uuid}" "Name=key,Values=rackuuid" --query 'Tags[*].Value[]' --output text`
home=`getent passwd magento | cut -d: -f6`

if [ ! -d ${home}/.ssh/ ];
then
  mkdir ${home}/.ssh/
  chown magento:magento ${home}/.ssh/
  restorecon -R ${home}/.ssh/
fi

while [ -z ${bucketexist} ]
do
  bucketexist=`/bin/aws s3 ls | grep "${keybucket}\-lsynckey"`
  sleep 5
done

if [ ! -z ${keybucket} ]
then
  /bin/aws s3 cp s3://${keybucket}-lsynckey/magento-admin.pub ${home}/.ssh/
  cat ${home}/.ssh/magento-admin.pub >> ${home}/.ssh/authorized_keys
  rm -f ${home}/.ssh/magento-admin.pub
  chown magento:magento ${home}/.ssh/magento-admin.pub ${home}/.ssh/authorized_keys
  restorecon -R ${home}/.ssh/
fi
