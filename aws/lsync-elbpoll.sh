#!/bin/bash

# The following IAM roles are required:
#   AmazonEC2ReadOnlyAccess

uuid=`curl -s http://169.254.169.254/latest/meta-data/instance-id`

if [ ! -f /tmp/awsregion ];
then
  echo `curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone/ | sed '$ s/.$//'` > /tmp/awsregion
  region=$(</tmp/awsregion)
else
  region=$(</tmp/awsregion)
fi

if [ ! -f /tmp/awstag ];
then
  echo `/usr/local/bin/aws ec2 describe-tags --region ${region} --filters "Name=resource-id,Values=${uuid}" "Name=key,Values=rackuuid" --query 'Tags[*].Value[]' --output text` > /tmp/awstag
  rackuuid=$(</tmp/awstag)
else
  rackuuid=$(</tmp/awstag)
fi

elblist=`/usr/local/bin/aws elb describe-load-balancers --region ${region} --query 'LoadBalancerDescriptions[].LoadBalancerName[]' --output text`
IFS=$'\t' read -ra elbcheck <<<"${elblist}"

for i in "${elbcheck[@]}"
do
  elbtag=`/usr/local/bin/aws elb describe-tags --load-balancer-name ${i} --region ${region} --query 'TagDescriptions[].Tags[].Value[]' --output text`

  if [[ ${elbtag} == *"${rackuuid}"* ]]
  then
    ec2names=`/usr/local/bin/aws elb describe-instance-health --load-balancer-name ${i} --region ${region} --query 'InstanceStates[].InstanceId[]' --output text`
    ec2addresses=`/usr/local/bin/aws ec2 describe-instances --region ${region} --filter Name=tag:rackuuid,Values=${rackuuid} --query 'Reservations[].Instances[].PrivateIpAddress[]' --instance-id ${ec2names} --output text`
    break
  fi
done

echo ${ec2addresses} > /tmp/awsec2webips
