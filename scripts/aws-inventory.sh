#!/bin/bash

echo "=== AWS RESOURCES INVENTORY ==="
echo "Executed at: $(date)"
echo

echo "=== EC2 INSTANCES ==="
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,LaunchTime]' --output table

echo "=== EKS CLUSTERS ==="
aws eks list-clusters --query 'clusters' --output table
for cluster in $(aws eks list-clusters --query 'clusters[]' --output text); do
    echo "Cluster: $cluster"
    aws eks describe-cluster --name "$cluster" --query 'cluster.[name,status,createdAt,version]' --output table
    echo
done

echo "=== RDS INSTANCES ==="
aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,Engine,DBInstanceClass,AllocatedStorage]' --output table

echo "=== LAMBDA FUNCTIONS ==="
aws lambda list-functions --query 'Functions[].[FunctionName,Runtime,LastModified]' --output table

echo "=== LOAD BALANCERS (ALB/NLB) ==="
aws elbv2 describe-load-balancers --query 'LoadBalancers[].[LoadBalancerName,Type,State.Code,CreatedTime]' --output table

echo "=== API GATEWAY REST APIs ==="
aws apigateway get-rest-apis --query 'items[].[name,id,createdDate]' --output table

echo "=== S3 BUCKETS ==="
aws s3 ls

echo "=== VPC INFORMATION ==="
aws ec2 describe-vpcs --query 'Vpcs[].[VpcId,State,CidrBlock,IsDefault]' --output table

echo "=== SECURITY GROUPS ==="
aws ec2 describe-security-groups --query 'SecurityGroups[].[GroupId,GroupName,Description,VpcId]' --output table

echo "=== NETWORK INTERFACES ==="
aws ec2 describe-network-interfaces --query 'NetworkInterfaces[].[NetworkInterfaceId,Status,InterfaceType,VpcId]' --output table

echo "=== IAM ROLES (filtered for project) ==="
aws iam list-roles --query 'Roles[?contains(RoleName, `lanchonete`) || contains(RoleName, `lambda`) || contains(RoleName, `eks`)].[RoleName,CreateDate]' --output table

echo "=== CLOUDWATCH LOG GROUPS ==="
aws logs describe-log-groups --query 'logGroups[].[logGroupName,creationTime,storedBytes]' --output table

echo "=== SECRETS MANAGER ==="
aws secretsmanager list-secrets --query 'SecretList[].[Name,LastChangedDate]' --output table

echo "=== NAT GATEWAYS ==="
aws ec2 describe-nat-gateways --query 'NatGateways[].[NatGatewayId,State,VpcId,SubnetId]' --output table

echo "=== INTERNET GATEWAYS ==="
aws ec2 describe-internet-gateways --query 'InternetGateways[].[InternetGatewayId,State,Tags[?Key==`Name`].Value|[0]]' --output table

echo "=== END OF INVENTORY ==="
