#!/bin/bash

# AWS Regions
REGIONS=("us-east-1" "us-east-2")

# Function to delete default VPCs and associated resources
delete_default_vpc() {
    REGION=$1
    echo "Processing region: $REGION"

    # Get the default VPC ID
    VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=is-default,Values=true --query "Vpcs[0].VpcId" --output text)

    if [[ "$VPC_ID" == "None" ]]; then
        echo "No default VPC found in $REGION"
        return
    fi

    echo "Found default VPC: $VPC_ID in $REGION"

    # Get and delete subnets
    SUBNETS=$(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" --query "Subnets[*].SubnetId" --output text)
    for SUBNET in $SUBNETS; do
        echo "Deleting subnet: $SUBNET"
        aws ec2 delete-subnet --region "$REGION" --subnet-id "$SUBNET"
    done

    # Get and delete internet gateways
    IGWS=$(aws ec2 describe-internet-gateways --region "$REGION" --filters Name=attachment.vpc-id,Values="$VPC_ID" --query "InternetGateways[*].InternetGatewayId" --output text)
    for IGW in $IGWS; do
        echo "Detaching and deleting internet gateway: $IGW"
        aws ec2 detach-internet-gateway --region "$REGION" --internet-gateway-id "$IGW" --vpc-id "$VPC_ID"
        aws ec2 delete-internet-gateway --region "$REGION" --internet-gateway-id "$IGW"
    done

    # Get and delete route tables (excluding main route table)
    RTBS=$(aws ec2 describe-route-tables --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" --query "RouteTables[?Associations[?Main==false]].RouteTableId" --output text)
    for RTB in $RTBS; do
        echo "Deleting route table: $RTB"
        aws ec2 delete-route-table --region "$REGION" --route-table-id "$RTB"
    done

    # Get and delete security groups (excluding default security group)
    SG_IDS=$(aws ec2 describe-security-groups --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
    for SG in $SG_IDS; do
        echo "Deleting security group: $SG"
        aws ec2 delete-security-group --region "$REGION" --group-id "$SG"
    done

    # Get and delete network ACLs (excluding default)
    ACL_IDS=$(aws ec2 describe-network-acls --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" --query "NetworkAcls[?IsDefault==false].NetworkAclId" --output text)
    for ACL in $ACL_IDS; do
        echo "Deleting network ACL: $ACL"
        aws ec2 delete-network-acl --region "$REGION" --network-acl-id "$ACL"
    done

    # Delete the default VPC
    echo "Deleting default VPC: $VPC_ID"
    aws ec2 delete-vpc --region "$REGION" --vpc-id "$VPC_ID"

    echo "Default VPC deleted in $REGION"
}

# Loop through each region
for REGION in "${REGIONS[@]}"; do
    delete_default_vpc "$REGION"
done

echo "All default VPCs and related resources deleted in specified regions."
