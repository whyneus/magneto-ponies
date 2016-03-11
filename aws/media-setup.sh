#!/bin/bash

# Script to setup S3 bucket for Magento's media/ (initial creation) or copy
# data onto local server if the bucket exists (healing process).

# The following IAM roles are required:
#   AmazonS3FullAccess
#   AmazonEC2ReadOnlyAccess

region=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone/ | sed '$ s/.$//'`
uuid=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
mediabucket="`/bin/aws ec2 describe-tags --region ${region} --filters "Name=resource-id,Values=${uuid}" "Name=key,Values=rackuuid" --query 'Tags[*].Value[]' --output text`"
bucketexist=`/bin/aws s3 ls | grep -c "${mediabucket}-media"`

if [ ! -d `getent passwd magento | cut -d: -f6`/httpdocs/media ]
then
  mkdir `getent passwd magento | cut -d: -f6`/httpdocs/media
fi

if [ ${bucketexist} != "1" ];
then
  /bin/aws s3 mb s3://${mediabucket}-media/
  /bin/aws s3api put-bucket-tagging --bucket ${mediabucket}-media --tagging "TagSet=[{Key=rackuuid,Value=${mediabucket}}]"
else
#  /bin/aws s3 cp
fi
