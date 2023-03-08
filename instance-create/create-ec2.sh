##!/bin/bash
#
# if [ -z "$1" ]; then
#   echo "Instance Name as argument is needed"
#   exit 1
# fi
#
# if [ "$1" == "list" ]; then
#   aws ec2 describe-instances  --query "Reservations[*].Instances[*].{PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,Name:Tags[?Key=='Name']|[0].Value,Status:State.Name}"  --output table
#   exit 0
# fi
#
# NAME=$1
#
# aws ec2 describe-spot-instance-requests --filters Name=tag:Name,Values=${NAME} Name=state,Values=active --output table | grep InstanceId &>/dev/null
# if [ $? -eq 0 ]; then
#   echo "Instance Already exists"
# else
#  AMI_ID=ami-06c286216c69df7a8
#  aws ec2 run-instances --image-id ${AMI_ID} --instance-type t3.micro --instance-market-options "MarketType=spot,SpotOptions={SpotInstanceType=persistent,InstanceInterruptionBehavior=stop}" --tag-specifications "ResourceType=spot-instances-request,Tags=[{Key=Name,Value=${NAME}}]" "ResourceType=instance,Tags=[{Key=Name,Value=${NAME}}]" --security-group-ids sg-032093c293a641723 &>/dev/null
#  echo EC2 Instance Created
#  sleep 30
#fi
# INSTANCE_ID=$(aws ec2 describe-spot-instance-requests --filters Name=tag:Name,Values=${NAME} Name=state,Values=active --output table | grep InstanceId | awk '{print $4}')
#
# IPADDRESS=$(aws ec2 describe-instances  --instance-ids ${INSTANCE_ID}  --output table | grep PrivateIpAddress | head -n 1 | awk '{print $4}')
#
# sed -e "s/COMPONENT/${NAME}/" -e "s/IPADDRESS/${IPADDRESS}/" route53.json >/tmp/route53.json
# aws route53 change-resource-record-sets --hosted-zone-id Z08351461XBOFH93FVJTZ --change-batch file:///tmp/route53.json &>/dev/null
# echo DNS Record Created

#!/bin/bash
##### Change these values ###
ZONE_ID="Z08351461XBOFH93FVJTZ"
SG_NAME="allow-all"
IAM_INSTANCE_PROFILE="Arn=arn:aws:iam::637261222008:instance-profile/full"
#############################

if [ -z "${1}" ] ; then
  ENV=""
else
  ENV="-$1"
fi
COMPONENT=all
create_ec2() {
  PRIVATE_IP=$(aws ec2 run-instances \
      --image-id ${AMI_ID} \
      --instance-type t2.micro \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${COMPONENT}${ENV}}, {Key=Monitor,Value=yes}]" \
      --instance-market-options "MarketType=spot,SpotOptions={SpotInstanceType=persistent,InstanceInterruptionBehavior=stop}"\
      --security-group-ids ${SGID} \
      --iam-instance-profile="${IAM_INSTANCE_PROFILE}" \
      | jq '.Instances[].PrivateIpAddress' | sed -e 's/"//g')

  sed -e "s/IPADDRESS/${PRIVATE_IP}/" -e "s/COMPONENT/${COMPONENT}${ENV}/" route53.json >/tmp/record.json
  aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch file:///tmp/record.json | jq
}

#AMI_ID=$(aws ec2 describe-images --filters "Name=name,Values=Centos-7-DevOps-Practice" | jq '.Images[].ImageId' | sed -e 's/"//g')
AMI_ID="ami-06c286216c69df7a8"
SGID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=${SG_NAME} | jq  '.SecurityGroups[].GroupId' | sed -e 's/"//g')

if [ "$COMPONENT" == "all" ]; then
  for component in catalogue cart user shipping payment frontend mongodb mysql rabbitmq redis ; do
    COMPONENT=$component
    create_ec2
  done
else
  create_ec2
fi
