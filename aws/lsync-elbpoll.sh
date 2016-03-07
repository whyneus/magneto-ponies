#!/bin/bash

# The following tags are required:
#   rackuuid - all resources related to the deployment should have the same tag
#              (eg. example.com-20160301)
#   rackrole - additional tag assigned to at least the ELB the admin server is behind
#              must be in the format rackuuid-admin (eg. example.com-20160301-admin)

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
  echo `/bin/aws ec2 describe-tags --region ${region} --filters "Name=resource-id,Values=${uuid}" "Name=key,Values=rackuuid" --query 'Tags[*].Value[]' --output text` > /tmp/awstag
  rackuuid=$(</tmp/awstag)
else
  rackuuid=$(</tmp/awstag)
fi

# Run through all ELBs in region to look for the one with the matching rackuuid tag but exclude the one with -admin suffix
# Output to /tmp/awsec2webips to allow use by other scripts

elblist=`/bin/aws elb describe-load-balancers --region ${region} --query 'LoadBalancerDescriptions[].LoadBalancerName[]' --output text`
IFS=$'\t' read -ra elbcheck <<<"${elblist}"
for i in "${elbcheck[@]}"
do
  elbtag=`/bin/aws elb describe-tags --load-balancer-name ${i} --region ${region} --query 'TagDescriptions[].Tags[].Value[]' --output text | grep -v "${rackuuid}-admin"`

  if [[ ${elbtag} == *"${rackuuid}"* ]]
  then
    ec2names=`/bin/aws elb describe-instance-health --load-balancer-name ${i} --region ${region} --query 'InstanceStates[].InstanceId[]' --output text`
    ec2addresses=`/bin/aws ec2 describe-instances --region ${region} --filter Name=tag:rackuuid,Values=${rackuuid} --query 'Reservations[].Instances[].PrivateIpAddress[]' --instance-id ${ec2names} --output text`
    break
  fi
done
echo ${ec2addresses} > /tmp/awsec2webips

# Install lsyncd

if ! rpm -qa | grep -qw lsyncd;
then
  yum -y install lsyncd
  systemctl enable lsyncd.service
  sysctl -w fs.inotify.max_user_watches=163840 >> /etc/sysctl.conf
  sysctl -p
  
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

# Create the initial lsyncd configuration files

if [ ! -f /etc/lsyncd-excludes ];
then
  echo "magento/.ssh/
magento/httpdocs/var/" >> /etc/lsyncd-excludes
fi

# Compare list of IPs behind ELB with previously retrieved list
# If there are differences, recreate lsyncd targets list

if [ ! -f /tmp/awslsyncips ];
then
  touch /tmp/awslsyncips
fi

webipchange=`diff /tmp/awsec2webips /tmp/awslsyncips`
if [[ ! -z ${webipchange} ]];
then
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
  systemctl restart lsyncd.service
fi
