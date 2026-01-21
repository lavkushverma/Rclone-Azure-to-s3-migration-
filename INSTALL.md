# Installation Guide

Complete installation instructions for the Azure to S3 Migration toolkit.

## Prerequisites

Before you begin, ensure you have:

- **Azure Account**: Active subscription with access to Storage Accounts
- **AWS Account**: Active account with EC2 and S3 access
- **EC2 Instance**: Linux instance (Ubuntu 22.04 or Amazon Linux 2023 recommended)
- **Permissions**: 
  - Azure: Ability to create Service Principals
  - AWS: Ability to create IAM roles and S3 buckets

## Installation Methods

### Method 1: Quick Install (Recommended)

```bash
# Clone the repository
git clone https://github.com/yourusername/azure-to-s3-migration.git
cd azure-to-s3-migration

# Run the automated setup
chmod +x scripts/setup.sh
./scripts/setup.sh
```

The setup script will:
1. Install rclone
2. Guide you through Azure configuration
3. Set up AWS credentials
4. Create configuration files
5. Test connectivity

### Method 2: Manual Installation

#### Step 1: Install Rclone

```bash
# Update sudo timestamp
sudo -v

# Download and install rclone
curl https://rclone.org/install.sh | sudo bash

# Verify installation
rclone version
```

#### Step 2: Clone Repository

```bash
git clone https://github.com/yourusername/azure-to-s3-migration.git
cd azure-to-s3-migration
```

#### Step 3: Configure Azure

1. **Create Service Principal** (on local machine with Azure CLI):

```bash
az login
az ad sp create-for-rbac \
  --name rclone-azure-sp \
  --role "Storage Blob Data Reader" \
  --scopes /subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Storage/storageAccounts/<STORAGE>
```

2. **Save credentials to EC2**:

```bash
mkdir -p ~/.config/rclone
nano ~/.config/rclone/azure-principal.json
```

Add the Service Principal details:
```json
{
  "appId": "your-app-id",
  "password": "your-password",
  "tenant": "your-tenant-id"
}
```

```bash
chmod 600 ~/.config/rclone/azure-principal.json
```

#### Step 4: Configure AWS

1. **Create IAM Role** (see `examples/aws-setup.sh` for detailed commands)

2. **Attach role to EC2 instance**:

```bash
aws ec2 associate-iam-instance-profile \
  --instance-id i-xxxxx \
  --iam-instance-profile Name=rclone-s3-migration-profile
```

#### Step 5: Configure Rclone

```bash
cp config/rclone.conf.template ~/.config/rclone/rclone.conf
nano ~/.config/rclone/rclone.conf
```

Update with your values:
- Azure storage account name
- Path to azure-principal.json
- AWS region

#### Step 6: Test Configuration

```bash
# List remotes
rclone listremotes

# Test Azure
rclone lsd AZStorageAccount:

# Test S3
rclone lsd s3:
```

### Method 3: Docker Installation (Coming Soon)

```bash
# Pull Docker image
docker pull yourusername/azure-to-s3-migration:latest

# Run container
docker run -it \
  -v ~/.config/rclone:/root/.config/rclone \
  yourusername/azure-to-s3-migration:latest
```

## Post-Installation

### 1. Verify Installation

```bash
# Check rclone version
rclone version

# Check configuration
rclone config show

# Test connectivity
rclone lsd AZStorageAccount: -v
rclone lsd s3: -v
```

### 2. Run Test Migration

```bash
# Create test file in Azure
az storage blob upload \
  --account-name YOUR_STORAGE \
  --container-name test \
  --name test.txt \
  --file test.txt

# Migrate test file
rclone copy AZStorageAccount:test/test.txt s3:your-bucket/test.txt --progress

# Verify in S3
aws s3 ls s3://your-bucket/test.txt
```

### 3. Configure Scripts

```bash
# Make scripts executable (if not already)
chmod +x scripts/*.sh
chmod +x examples/*.sh

# Test scripts
./scripts/verify.sh --help
```

## Troubleshooting Installation

### Rclone Installation Issues

**Issue**: Permission denied during installation
```bash
# Solution: Ensure you have sudo access
sudo -v
```

**Issue**: Command not found after installation
```bash
# Solution: Verify installation path
which rclone
echo $PATH

# Add to PATH if needed
export PATH=$PATH:/usr/local/bin
```

### Azure Configuration Issues

**Issue**: Cannot create Service Principal
```bash
# Solution: Check Azure permissions
az account show
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

**Issue**: Service Principal authentication fails
```bash
# Solution: Verify JSON format
cat ~/.config/rclone/azure-principal.json | jq .

# Test Service Principal
az login --service-principal \
  -u YOUR_APP_ID \
  -p YOUR_PASSWORD \
  --tenant YOUR_TENANT
```

### AWS Configuration Issues

**Issue**: No IAM role attached
```bash
# Solution: Verify IAM role
aws sts get-caller-identity

# Check instance metadata
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

**Issue**: S3 access denied
```bash
# Solution: Verify IAM permissions
aws iam get-role-policy \
  --role-name YOUR_ROLE \
  --policy-name YOUR_POLICY
```

### Rclone Configuration Issues

**Issue**: Remote not found
```bash
# Solution: Check config file
rclone config show
rclone listremotes

# Verify remote names match config
cat ~/.config/rclone/rclone.conf
```

**Issue**: Path to azure-principal.json incorrect
```bash
# Solution: Use absolute path
echo $HOME
ls -la ~/.config/rclone/azure-principal.json

# Update rclone.conf with correct path
nano ~/.config/rclone/rclone.conf
```

## Updating

### Update Rclone

```bash
# Update to latest version
sudo -v
curl https://rclone.org/install.sh | sudo bash

# Verify new version
rclone version
```

### Update Repository

```bash
cd azure-to-s3-migration
git pull origin main

# Make scripts executable again
chmod +x scripts/*.sh examples/*.sh
```

## Uninstallation

### Remove Rclone

```bash
# Remove rclone binary
sudo rm $(which rclone)

# Remove configuration
rm -rf ~/.config/rclone
rm -rf ~/.cache/rclone
```

### Clean Up Azure Resources

```bash
# Delete Service Principal
az ad sp delete --id YOUR_APP_ID

# Verify deletion
az ad sp list --display-name rclone-azure-sp
```

### Clean Up AWS Resources

```bash
# Remove IAM role from instance
aws ec2 disassociate-iam-instance-profile --association-id xxxxx

# Delete instance profile
aws iam remove-role-from-instance-profile \
  --instance-profile-name rclone-s3-migration-profile \
  --role-name rclone-s3-migration-role

aws iam delete-instance-profile \
  --instance-profile-name rclone-s3-migration-profile

# Detach and delete policy
aws iam detach-role-policy \
  --role-name rclone-s3-migration-role \
  --policy-arn arn:aws:iam::ACCOUNT:policy/RcloneS3MigrationPolicy

aws iam delete-policy \
  --policy-arn arn:aws:iam::ACCOUNT:policy/RcloneS3MigrationPolicy

# Delete role
aws iam delete-role --role-name rclone-s3-migration-role
```

## Next Steps

After successful installation:

1. Review the [Quick Reference](QUICK_REFERENCE.md) for common commands
2. Read [Best Practices](docs/BEST_PRACTICES.md) for migration planning
3. Check [Troubleshooting Guide](docs/TROUBLESHOOTING.md) if issues arise
4. Run test migration with small dataset
5. Plan and execute production migration

## Getting Help

- **Documentation**: Check `docs/` directory
- **Issues**: Report bugs on GitHub Issues
- **Community**: Join discussions on GitHub
- **Commercial Support**: Contact for enterprise support

## System Requirements

### Minimum Requirements
- 2 vCPU
- 4 GB RAM
- 20 GB disk space
- 10 Mbps network

### Recommended for Large Migrations (>1TB)
- 4+ vCPU
- 16+ GB RAM
- 100+ GB disk space
- 1+ Gbps network

### Supported Operating Systems
- Ubuntu 20.04 LTS or later
- Amazon Linux 2023
- Debian 11 or later
- RHEL 8 or later
- CentOS 8 or later

## Additional Tools (Optional)

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# jq (JSON processor)
sudo apt install jq -y  # Ubuntu/Debian
sudo yum install jq -y  # Amazon Linux/RHEL

# screen (terminal multiplexer)
sudo apt install screen -y  # Ubuntu/Debian
sudo yum install screen -y  # Amazon Linux/RHEL
```

## Support Matrix

| Component | Version | Status |
|-----------|---------|--------|
| Rclone | 1.65+ | ✅ Supported |
| Ubuntu | 20.04+ | ✅ Supported |
| Amazon Linux | 2023 | ✅ Supported |
| Debian | 11+ | ✅ Supported |
| RHEL | 8+ | ✅ Supported |
| CentOS | 8+ | ✅ Supported |

---

For detailed setup instructions, see [SETUP.md](docs/SETUP.md)
