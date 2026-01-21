# Azure Blob Storage to AWS S3 Migration using Rclone

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Rclone](https://img.shields.io/badge/rclone-v1.65+-blue.svg)](https://rclone.org/)

A complete guide and automation scripts for migrating data from Azure Blob Storage to AWS S3 using rclone with Azure Service Principal authentication.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Usage](#usage)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

This repository provides a streamlined process for migrating large-scale data from Azure Blob Storage to AWS S3 using rclone. It includes:

- Automated setup scripts
- Service Principal authentication for Azure
- IAM role-based authentication for AWS
- Progress monitoring and verification tools
- Production-ready configurations

## ✅ Prerequisites

### Azure Requirements
- Azure subscription with access to Storage Account
- Permissions to create Service Principals
- Azure CLI installed (`az` command)
- Storage Account name and Resource Group name

### AWS Requirements
- AWS account with S3 access
- EC2 instance with IAM role attached OR AWS credentials configured
- IAM permissions for S3 operations (read/write/list)

### EC2 Instance
- Ubuntu/Debian-based Linux (recommended)
- Sufficient disk space for temporary operations
- Network connectivity to both Azure and AWS

## 🚀 Quick Start

```bash
# Clone this repository
git clone https://github.com/yourusername/azure-to-s3-migration.git
cd azure-to-s3-migration

# Run the setup script
chmod +x scripts/setup.sh
./scripts/setup.sh

# Follow the interactive prompts to configure Azure and AWS
```

## 📖 Detailed Setup

### Step 1: Install Rclone on EC2

```bash
# Update sudo timestamp and install rclone
sudo -v
curl https://rclone.org/install.sh | sudo bash

# Verify installation
rclone version
```

### Step 2: Create Azure Service Principal

On your local machine or Azure Cloud Shell:

```bash
# Create Service Principal with Storage Blob Data Reader role
az ad sp create-for-rbac \
  --name rclone-azure-sp \
  --role "Storage Blob Data Reader" \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.Storage/storageAccounts/<STORAGE_ACCOUNT_NAME>
```

**Sample Output:**
```json
{
  "appId": "06d81512-6769-4b21-8397-b4181143ed46",
  "password": "2xq8Q~8CH_w0xfHwgBH1GwxY~VwAuJtWfjuwOauD",
  "tenant": "eedb35ab-700a-4a39-9870-d3656b5fef95"
}
```

### Step 3: Configure Rclone on EC2

#### Create Azure Principal Configuration File

```bash
# Create rclone config directory
mkdir -p ~/.config/rclone

# Create and edit the Azure principal file
nano ~/.config/rclone/azure-principal.json
```

**Add the following content** (replace with your values):

```json
{
  "appId": "YOUR_APP_ID",
  "password": "YOUR_PASSWORD",
  "tenant": "YOUR_TENANT_ID"
}
```

#### Create Rclone Configuration File

```bash
# Edit rclone configuration
nano ~/.config/rclone/rclone.conf
```

**Add the following configuration:**

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

**Important:** Update the `service_principal_file` path to match your EC2 user's home directory:
- Amazon Linux: `/home/ec2-user/.config/rclone/azure-principal.json`
- Ubuntu: `/home/ubuntu/.config/rclone/azure-principal.json`
- Custom user: `/home/YOUR_USERNAME/.config/rclone/azure-principal.json`

### Step 4: Configure AWS IAM Role (EC2)

Ensure your EC2 instance has an IAM role with S3 permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket-name",
        "arn:aws:s3:::your-bucket-name/*"
      ]
    }
  ]
}
```

## 💻 Usage

### Verify Configuration

```bash
# List configured remotes
rclone listremotes

# List Azure containers
rclone lsd AZStorageAccount:

# List S3 buckets
rclone lsd s3:
```

### Check Storage Sizes

```bash
# Check Azure Blob Storage size
rclone size AZStorageAccount:

# Check specific Azure container
rclone size AZStorageAccount:container-name

# Check S3 bucket size
rclone size s3:your-bucket-name
```

### Perform Migration

#### Basic Copy (All Containers)

```bash
# Copy all data from Azure to S3 with progress
rclone copy AZStorageAccount: s3:your-bucket-name --progress
```

#### Copy Specific Container

```bash
# Copy specific Azure container to S3 bucket
rclone copy AZStorageAccount:container-name s3:your-bucket-name/prefix --progress
```

#### Advanced Copy with Options

```bash
# Copy with multiple threads, checksum verification, and logging
rclone copy AZStorageAccount:container-name s3:your-bucket-name \
  --progress \
  --transfers 32 \
  --checkers 16 \
  --checksum \
  --log-file=migration.log \
  --log-level INFO \
  --stats 1m \
  --stats-one-line
```

### Sync vs Copy

```bash
# Copy: Only copies new or changed files (doesn't delete)
rclone copy AZStorageAccount:container s3:bucket --progress

# Sync: Makes destination identical to source (deletes extra files)
rclone sync AZStorageAccount:container s3:bucket --progress --dry-run
# Remove --dry-run when ready to execute
```

## ✔️ Verification

### Compare File Counts

```bash
# Count files in Azure
rclone size AZStorageAccount:container-name

# Count files in S3
rclone size s3:bucket-name
```

### Verify Checksums

```bash
# Check for differences between source and destination
rclone check AZStorageAccount:container-name s3:bucket-name --one-way
```

### List Differences

```bash
# Show files that differ
rclone check AZStorageAccount:container-name s3:bucket-name --one-way --combined combined.log
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Authentication Errors

**Azure:**
```bash
# Verify Service Principal has correct permissions
az role assignment list --assignee <appId>

# Test Azure connectivity
rclone lsd AZStorageAccount: -v
```

**AWS:**
```bash
# Verify IAM role is attached to EC2
aws sts get-caller-identity

# Test S3 connectivity
rclone lsd s3: -v
```

#### 2. Path Issues

Ensure the `service_principal_file` path is absolute and correct:
```bash
# Find your home directory
echo $HOME

# Update path in rclone.conf accordingly
```

#### 3. Permission Denied

```bash
# Check file permissions
ls -la ~/.config/rclone/

# Set correct permissions
chmod 600 ~/.config/rclone/azure-principal.json
chmod 644 ~/.config/rclone/rclone.conf
```

### Enable Debug Logging

```bash
# Run with verbose debugging
rclone copy AZStorageAccount:container s3:bucket -vv --log-file=debug.log
```

## 🎯 Best Practices

1. **Test First**: Always run with `--dry-run` flag first
   ```bash
   rclone copy source: dest: --dry-run
   ```

2. **Use Bandwidth Limits**: Prevent network saturation
   ```bash
   rclone copy source: dest: --bwlimit 10M
   ```

3. **Resume Failed Transfers**: Rclone automatically skips existing files
   ```bash
   rclone copy source: dest: --progress
   ```

4. **Monitor Progress**: Use screen or tmux for long transfers
   ```bash
   screen -S migration
   rclone copy source: dest: --progress
   # Detach: Ctrl+A, D
   # Reattach: screen -r migration
   ```

5. **Parallel Transfers**: Adjust based on your bandwidth
   ```bash
   rclone copy source: dest: --transfers 32 --checkers 16
   ```

6. **Log Everything**: Keep detailed logs for audit trails
   ```bash
   rclone copy source: dest: --log-file=migration-$(date +%Y%m%d).log
   ```

## 📊 Performance Optimization

### Recommended Settings for Large Migrations

```bash
rclone copy AZStorageAccount:container s3:bucket \
  --transfers 32 \
  --checkers 16 \
  --buffer-size 256M \
  --s3-upload-concurrency 16 \
  --stats 1m \
  --progress \
  --log-file=migration.log
```

### Settings Explanation
- `--transfers`: Number of parallel file transfers (default: 4)
- `--checkers`: Number of parallel checkers (default: 8)
- `--buffer-size`: Size of in-memory buffer for each transfer
- `--s3-upload-concurrency`: Number of chunks to upload in parallel for multipart
- `--stats`: How often to print statistics

## 📝 Migration Checklist

- [ ] Azure Service Principal created with appropriate permissions
- [ ] EC2 instance has IAM role with S3 access
- [ ] Rclone installed and configured
- [ ] Test connection to both Azure and AWS
- [ ] Run dry-run migration
- [ ] Execute actual migration
- [ ] Verify file counts and sizes
- [ ] Run checksum verification
- [ ] Document migration results
- [ ] Clean up temporary files and logs

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Rclone](https://rclone.org/) - The amazing sync tool
- Azure and AWS documentation teams

## 📞 Support

If you encounter any issues or have questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review [Rclone documentation](https://rclone.org/docs/)
3. Open an issue in this repository

## 🔗 Useful Links

- [Rclone Official Documentation](https://rclone.org/docs/)
- [Azure Blob Storage Documentation](https://docs.microsoft.com/azure/storage/blobs/)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [Azure Service Principal Guide](https://docs.microsoft.com/azure/active-directory/develop/howto-create-service-principal-portal)

---

**⚠️ Important Security Notes:**
- Never commit `azure-principal.json` to version control
- Rotate Service Principal credentials regularly
- Use least-privilege IAM policies
- Monitor migration logs for any anomalies
