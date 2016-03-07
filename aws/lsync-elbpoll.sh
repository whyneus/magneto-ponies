#!/bin/bash

# The following IAM roles are required:
#   AmazonEC2ReadOnlyAccess

# Grab needed info and output them to file to reduce API requests

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

# Run through all ELBs in region to look for the one with the matching rackuuid tag but exclude the one with -admin suffix
# Output to /tmp/awsec2webips to allow use by other scripts

elblist=`/usr/local/bin/aws elb describe-load-balancers --region ${region} --query 'LoadBalancerDescriptions[].LoadBalancerName[]' --output text`
IFS=$'\t' read -ra elbcheck <<<"${elblist}"
for i in "${elbcheck[@]}"
do
  elbtag=`/usr/local/bin/aws elb describe-tags --load-balancer-name ${i} --region ${region} --query 'TagDescriptions[].Tags[].Value[]' --output text | grep -v "${rackuuid}-admin"`

  if [[ ${elbtag} == *"${rackuuid}"* ]]
  then
    ec2names=`/usr/local/bin/aws elb describe-instance-health --load-balancer-name ${i} --region ${region} --query 'InstanceStates[].InstanceId[]' --output text`
    ec2addresses=`/usr/local/bin/aws ec2 describe-instances --region ${region} --filter Name=tag:rackuuid,Values=${rackuuid} --query 'Reservations[].Instances[].PrivateIpAddress[]' --instance-id ${ec2names} --output text`
    break
  fi
done
echo ${ec2addresses} > /tmp/awsec2webips

# Compare list of IPs behind ELB with previously retrieved list
# If there are differences, recreate lsyncd targets list

if [ ! -f /tmp/awslsyncips ];
then
  /bin/cp -f /tmp/awsec2webips /tmp/awslsyncips
fi

webipchange=`cmp /tmp/awsec2webips /tmp/awslsyncips`
if [[ ! -z ${webipchange} ]];
then

echo creating server list

  IFS=$'\t' read -ra lsynclist <<<"${ec2addresses}"
  webheadnumber=${#lsynclist[@]}
  webheadnumbercounter=1
  echo "servers = {" > /etc/lsyncd-targets
  for i in "${lsynclist[@]}"
  do
    if [[ ${webheadnumbercounter} -lt ${webheadnumber} ]]
    then
      echo "  \"${i}\"," >> /etc/lsyncd-targets
      webheadnumbercounter=$[${webheadnumbercounter}+1]
    else
      echo "  \"${i}\"" >> /etc/lsyncd-targets
    fi
  done
  echo  "}" >> /etc/lsyncd-targets
  /bin/cp -f /tmp/awsec2webips /tmp/awslsyncips
fi

# Create the initial lsyncd configuration files

if [ ! -f /etc/lsyncd-excludes ];
then
  echo "magento/.ssh/
magento/httpdocs/media/
magento/httpdocs/var/" >> /etc/lsyncd-excludes
fi

defaultlsyncconf=`grep -v ^\\-\\- /etc/lsyncd.conf`
if [[ -z ${defaultlsyncconf} ]]
then
  echo "settings {
  logfile    = \"/var/log/lsyncd/lsyncd.log\",
  statusFile = \"/var/log/lsyncd/lsyncd-status.log\",
  insist = 1,
  statusInterval = 20
}

dofile(\"/etc/lsyncd-targets\")

for _, server in ipairs(servers) do
sync {
    default.rsyncssh,
    source=\"/var/www/vhosts/\",
    host=server,
    targetdir=\"/var/www/vhosts/\",
    excludeFrom=\"/etc/lsyncd-excludes\",
    rsync = {
     archive = true,
     acls = true,
     verbose = true,
     rsh = \"/usr/bin/ssh -p 22 -i `getent passwd magento | cut -d: -f6`/.ssh/magento-admin -o StrictHostKeyChecking=no\"
   },
}
end" > /etc/lsyncd.conf
fi
