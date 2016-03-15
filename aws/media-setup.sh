#!/bin/bash

# The following IAM roles are required:
#   AmazonS3FullAccess
#   AmazonEC2ReadOnlyAccess

user="magento"
region=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone/ | sed '$ s/.$//'`
uuid=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
mediabucket="`/bin/aws ec2 describe-tags --region ${region} --filters "Name=resource-id,Values=${uuid}" "Name=key,Values=rackuuid" --query 'Tags[*].Value[]' --output text`"
bucketexist=`/bin/aws s3 ls | grep -c "${mediabucket}-media"`
home=`getent passwd ${user} | cut -d: -f6`

if [ ! -d ${home}/httpdocs/media ]
then
  mkdir ${home}/httpdocs/media
fi

if [ ${bucketexist} != "1" ];
then
  /bin/aws s3 mb s3://${mediabucket}-media/ --region ${region}
  /bin/aws s3api put-bucket-tagging --bucket ${mediabucket}-media --tagging "TagSet=[{Key=rackuuid,Value=${mediabucket}}]"
else
  /bin/aws s3 sync s3://${mediabucket}-media/ ${home}/httpdocs/media/ --delete --quiet
  chown -R ${user}:${user} ${home}/httpdocs/media
fi
