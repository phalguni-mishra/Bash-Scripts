#!/bin/bash

# Set your AWS region and credentials
AWS_REGION="ap-south-1"
AWS_ACCESS_KEY_ID="AKIA4T4TVLEQIFVDPN63"
AWS_SECRET_ACCESS_KEY="JO5P1ofyiD1Ude0ab7uCtgMdTbs3DRgM9iSn4NDX"

# Security group settings
INSTANCE_TYPE="t2.micro"
AMI_ID="ami-0f5ee92e2d63afc18"  

SECURITY_GROUP_NAME="SiddhantSecurity"
SECURITY_GROUP_DESCRIPTION="My-security "
SSH_PORT=22

# Key pair settings
KEY_NAME="siddhant-pair"

# Other settings
INSTANCE_NAME="EC2Instance"


# Create VPC
echo "Creating VPC..."
vpc_id=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region $AWS_REGION --output text --query 'Vpc.VpcId')
echo "VPC created. VPC ID: $vpc_id"


# Create subnet inside VPC
echo "Creating subnet..."
subnet_id=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.0.0.0/24 --region $AWS_REGION --output text --query 'Subnet.SubnetId')
echo "Subnet created. Subnet ID: $subnet_id"



# Create internet gateway
echo "Creating internet gateway..."
gateway_id=$(aws ec2 create-internet-gateway --region $AWS_REGION --output text --query 'InternetGateway.InternetGatewayId')
echo "Internet gateway created. Gateway ID: $gateway_id"

# Attach internet gateway to VPC
echo "Attaching internet gateway to VPC..."
aws ec2 attach-internet-gateway --internet-gateway-id $gateway_id --vpc-id $vpc_id --region $AWS_REGION
echo "Internet gateway attached to VPC."




# Create route table for the VPC
echo "Creating route table..."
route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id --region $AWS_REGION --output text --query 'RouteTable.RouteTableId')
echo "Route table created. Route table ID: $route_table_id"



# Add a route to the internet gateway in the route table
echo "Adding route to the internet gateway in the route table..."
aws ec2 create-route --route-table-id $route_table_id --destination-cidr-block 0.0.0.0/0 --gateway-id $gateway_id --region $AWS_REGION
echo "Route added to the internet gateway."



# Associate the route table with the subnet
echo "Associating the route table with the subnet..."
aws ec2 associate-route-table --subnet-id $subnet_id --route-table-id $route_table_id --region $AWS_REGION
echo "Route table associated with the subnet."



# Create an EC2 key pair
# aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$KEY_NAME.pem"



gid=$(aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME --description "$SECURITY_GROUP_DESCRIPTION" --vpc-id $vpc_id --region $AWS_REGION --output text --query 'GroupId')
echo $vpc_id

aws ec2 authorize-security-group-ingress --group-id "$gid" --protocol tcp --port $SSH_PORT --cidr 0.0.0.0/0

# Set appropriate permissions for the private key file
chmod 400 "$KEY_NAME.pem"

# Launch EC2 instance
echo "Launching EC2 instance..."
instance_id=$(aws ec2 run-instances --image-id ami-0f5ee92e2d63afc18 --instance-type t2.micro --security-group-id $gid --subnet-id $subnet_id --region $AWS_REGION --associate-public-ip-address --output text --query 'Instances[0].InstanceId')
echo "EC2 instance launched. Instance ID: $instance_id"

# Wait for the instance to be running
echo "Waiting for the instance to be running..."
aws ec2 wait instance-running --instance-ids $instance_id --region $AWS_REGION
echo "Instance is running."

# Get the public IP address of the EC2 instance
public_ip=$(aws ec2 describe-instances --instance-ids $instance_id --region $AWS_REGION --output text --query 'Reservations[0].Instances[0].PublicIpAddress')
echo "Public IP address of the EC2 instance: $public_ip"

# SSH into the EC2 instance
echo "SSHing into the EC2 instance..."
ssh -i "$KEY_NAME.pem" ubuntu@$public_ip
echo "SSH session completed."

sleep 1m 30s

#Clean up resources (comment this section out if you want to keep the resources)
echo "Cleaning up resources..."
aws ec2 terminate-instances --instance-ids $instance_id --region $AWS_REGION
aws ec2 wait instance-terminated --instance-ids $instance_id --region $AWS_REGION
aws ec2 detach-internet-gateway --internet-gateway-id $gateway_id --vpc-id $vpc_id --region $AWS_REGION
aws ec2 delete-internet-gateway --internet-gateway-id $gateway_id --region $AWS_REGION
aws ec2 disassociate-route-table --association-id $route_association_id --region $AWS_REGION
aws ec2 delete-route-table --route-table-id $route_table_id --region $AWS_REGION
aws ec2 delete-subnet --subnet-id $subnet_id --region $AWS_REGION
aws ec2 delete-vpc --vpc-id $vpc_id --region $AWS_REGION
echo "Resources cleaned up."
echo "Script execution complete."
