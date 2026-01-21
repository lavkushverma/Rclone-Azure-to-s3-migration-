# Detailed Setup Guide

This guide provides step-by-step instructions for setting up the Azure to S3 migration environment.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [EC2 Instance Setup](#ec2-instance-setup)
3. [Azure Configuration](#azure-configuration)
4. [AWS Configuration](#aws-configuration)
5. [Rclone Configuration](#rclone-configuration)
6. [Testing the Setup](#testing-the-setup)

## Prerequisites

### Azure Requirements

- Azure subscription
- Azure CLI installed on your local machine
- Owner or Contributor role on the Resource Group
- Storage Account already created

### AWS Requirements

- AWS account
- EC2 instance (t3.medium or larger recommended)
- IAM permissions to create and attach roles

## EC2 Instance Setup

### 1. Launch EC2 Instance

```bash
# Recommended specifications:
# - Instance Type: t3.medium (2 vCPU, 4 GB RAM) or larger
# - OS: Ubuntu 22.04 LTS or Amazon Linux 2023
# - Storage: 50 GB GP3 (adjust based on data size)
# - Network: Public subnet with internet gateway
```

### 2. Connect to EC2

```bash
# SSH into your instance
ssh -i your-key.pem ec2-user@your-instance-ip
# or for Ubuntu
ssh -i your-key.pem ubuntu@your-instance-ip
```

### 3. Update System

```bash
# For Amazon Linux / RedHat
sudo yum update -y

# For Ubuntu / Debian
sudo apt update && sudo apt upgrade -y
```

### 4. Install Required Tools

```bash
# Install AWS CLI (if not present)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

# Install jq for JSON parsing (optional but useful)
sudo yum install jq -y  # Amazon Linux
sudo apt install jq -y  # Ubuntu
```

## Azure Configuration

### 1. Login to Azure

```bash
# On your local machine
az login

# List subscriptions
az account list --output table

# Set active subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 2. Get Resource Information

```bash
# List resource groups
az group list --output table

# List storage accounts in a resource group
az storage account list --resource-group YOUR_RG --output table

# Get storage account details
az storage account show \
  --name YOUR_STORAGE_ACCOUNT \
  --resource-group YOUR_RG
```

### 3. Create Service Principal

```bash
# Get the full resource ID of your storage account
STORAGE_ID=$(az storage account show \
  --name YOUR_STORAGE_ACCOUNT \
  --resource-group YOUR_RG \
  --query id \
  --output tsv)

# Create Service Principal with Storage Blob Data Reader role
az ad sp create-for-rbac \
  --name rclone-azure-sp \
  --role "Storage Blob Data Reader" \
  --scopes $STORAGE_ID

# Save the output - you'll need it!
```

**Output will look like:**
```json
{
  "appId": "12345678-1234-1234-1234-123456789012",
  "displayName": "rclone-azure-sp",
  "password": "abcdefgh-1234-5678-90ab-cdefghijklmn",
  "tenant": "87654321-4321-4321-4321-210987654321"
}
```

### 4. Verify Service Principal Permissions

```bash
# List role assignments
az role assignment list \
  --assignee YOUR_APP_ID \
  --output table

# Test access (optional)
az storage blob list \
  --account-name YOUR_STORAGE_ACCOUNT \
  --container-name YOUR_CONTAINER \
  --auth-mode login
```

## AWS Configuration

### 1. Create IAM Role for EC2

**Option A: Using AWS Console**

1. Go to IAM → Roles → Create Role
2. Select "AWS Service" → "EC2"
3. Attach policies:
   - Create custom policy or use AmazonS3FullAccess (for testing)
4. Name: `rclone-s3-migration-role`
5. Create role

**Option B: Using AWS CLI**

```bash
# Create trust policy
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name rclone-s3-migration-role \
  --assume-role-policy-document file://trust-policy.json

# Create S3 policy
cat > s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket-name",
        "arn:aws:s3:::your-bucket-name/*"
      ]
    }
  ]
}
EOF

# Attach policy to role
aws iam put-role-policy \
  --role-name rclone-s3-migration-role \
  --policy-name S3MigrationPolicy \
  --policy-document file://s3-policy.json

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name rclone-s3-migration-profile

# Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name rclone-s3-migration-profile \
  --role-name rclone-s3-migration-role
```

### 2. Attach IAM Role to EC2

```bash
# Get your instance ID
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)

# Attach instance profile
aws ec2 associate-iam-instance-profile \
  --instance-id $INSTANCE_ID \
  --iam-instance-profile Name=rclone-s3-migration-profile

# Verify
aws sts get-caller-identity
```

### 3. Create S3 Bucket (if needed)

```bash
# Create bucket
aws s3 mb s3://your-migration-bucket --region ap-south-1

# Enable versioning (optional, for safety)
aws s3api put-bucket-versioning \
  --bucket your-migration-bucket \
  --versioning-configuration Status=Enabled

# Set lifecycle policy (optional)
cat > lifecycle.json <<EOF
{
  "Rules": [
    {
      "Id": "DeleteOldVersions",
      "Status": "Enabled",
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 90
      }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket your-migration-bucket \
  --lifecycle-configuration file://lifecycle.json
```

## Rclone Configuration

### 1. Install Rclone

```bash
# Update sudo timestamp
sudo -v

# Install rclone
curl https://rclone.org/install.sh | sudo bash

# Verify installation
rclone version
```

### 2. Create Configuration Directory

```bash
mkdir -p ~/.config/rclone
chmod 700 ~/.config/rclone
```

### 3. Create Azure Principal File

```bash
# Create the file
nano ~/.config/rclone/azure-principal.json
```

**Add content** (replace with your values from Azure SP creation):

```json
{
  "appId": "your-app-id-here",
  "password": "your-password-here",
  "tenant": "your-tenant-id-here"
}
```

```bash
# Secure the file
chmod 600 ~/.config/rclone/azure-principal.json
```

### 4. Create Rclone Configuration

```bash
# Create the config file
nano ~/.config/rclone/rclone.conf
```

**Add content** (update with your values):

```ini
[AZStorageAccount]
type = azureblob
account = your-azure-storage-name
service_principal_file = /home/ec2-user/.config/rclone/azure-principal.json

[s3]
type = s3
provider = AWS
env_auth = true
region = ap-south-1
```

**Important:** Update the `service_principal_file` path:
- Find your home: `echo $HOME`
- Amazon Linux: `/home/ec2-user/...`
- Ubuntu: `/home/ubuntu/...`

```bash
# Secure the file
chmod 644 ~/.config/rclone/rclone.conf
```

## Testing the Setup

### 1. Verify Rclone Configuration

```bash
# Show configuration
rclone config show

# List configured remotes
rclone listremotes
```

### 2. Test Azure Connection

```bash
# List containers
rclone lsd AZStorageAccount:

# List blobs in a container
rclone ls AZStorageAccount:container-name

# Get container size
rclone size AZStorageAccount:container-name
```

### 3. Test S3 Connection

```bash
# List buckets
rclone lsd s3:

# List objects in bucket
rclone ls s3:bucket-name

# Get bucket size
rclone size s3:bucket-name
```

### 4. Test Migration (Dry Run)

```bash
# Dry run migration
rclone copy AZStorageAccount:container s3:bucket \
  --dry-run \
  --progress \
  --stats 1m

# Dry run with verbose output
rclone copy AZStorageAccount:container s3:bucket \
  --dry-run \
  -v \
  --log-file=dryrun.log
```

### 5. Small Test Migration

```bash
# Create test file in Azure (using Azure CLI)
echo "test content" > test.txt
az storage blob upload \
  --account-name YOUR_STORAGE \
  --container-name YOUR_CONTAINER \
  --name test.txt \
  --file test.txt \
  --auth-mode login

# Migrate single file
rclone copy AZStorageAccount:container/test.txt s3:bucket/test.txt -v

# Verify in S3
aws s3 ls s3://bucket/test.txt
```

## Troubleshooting

### Azure Issues

```bash
# Check Service Principal exists
az ad sp list --display-name rclone-azure-sp

# Check role assignments
az role assignment list --assignee YOUR_APP_ID

# Test with verbose logging
rclone lsd AZStorageAccount: -vv
```

### AWS Issues

```bash
# Verify IAM role
aws sts get-caller-identity

# Check S3 permissions
aws s3 ls s3://your-bucket --debug

# Test with different region
aws s3 ls --region ap-south-1
```

### Rclone Issues

```bash
# Check config file syntax
rclone config show

# Test with debug logging
rclone lsd AZStorageAccount: -vv --log-file=debug.log

# Verify paths
ls -la ~/.config/rclone/
```

## Next Steps

Once setup is complete:

1. Run verification script: `./scripts/verify.sh`
2. Plan migration strategy
3. Execute migration: `./scripts/migrate.sh`
4. Monitor progress
5. Verify completion

## Additional Resources

- [Rclone Azure Blob Documentation](https://rclone.org/azureblob/)
- [Rclone S3 Documentation](https://rclone.org/s3/)
- [Azure Service Principal Guide](https://learn.microsoft.com/azure/active-directory/develop/howto-create-service-principal-portal)
- [AWS IAM Roles for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)
