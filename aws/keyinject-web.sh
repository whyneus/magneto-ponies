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
s3count=`/bin/aws s3 ls s3://${keybucket}-media/ --recursive --summarize --region ${region} | grep ^Total\ Objects | awk '{print $3}'`

if [ ! -d ${home}/.ssh/ ];
then
  mkdir ${home}/.ssh/
  chown magento:magento ${home}/.ssh/
  restorecon -R ${home}/.ssh/
fi

while [ -z ${bucketexist} ]
do
  bucketexist=`/bin/aws s3 ls --region ${region} | grep "${keybucket}\-lsynckey"`
  sleep 5
done

if [ ! -z ${keybucket} ]
then
  /bin/aws s3 cp s3://${keybucket}-lsynckey/magento-admin.pub ${home}/.ssh/ --region ${region}
  cat ${home}/.ssh/magento-admin.pub >> ${home}/.ssh/authorized_keys
  rm -f ${home}/.ssh/magento-admin.pub
  chown magento:magento ${home}/.ssh/magento-admin.pub ${home}/.ssh/authorized_keys
  restorecon -R ${home}/.ssh/
fi

while [[ ${localcount} -lt $((${s3count}-20)) ]]
do
  sleep 30
  localcount=`find /var/www/vhosts/magento/httpdocs/media/ | wc -l`
done
if [[ ${localcount} -gt $((${s3count}-20)) ]]
then
  echo "<?php echo \"OK\"; ?>" > /var/www/vhosts/magento/httpdocs/rs-healthc.php
fi
