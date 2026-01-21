# Best Practices for Azure to S3 Migration

This guide outlines recommended practices for successful data migration from Azure Blob Storage to AWS S3.

## Table of Contents

1. [Pre-Migration Planning](#pre-migration-planning)
2. [Security Best Practices](#security-best-practices)
3. [Performance Optimization](#performance-optimization)
4. [Data Validation](#data-validation)
5. [Cost Optimization](#cost-optimization)
6. [Operational Best Practices](#operational-best-practices)

## Pre-Migration Planning

### 1. Assess Your Data

```bash
# Get total size of data to migrate
rclone size AZStorageAccount:

# List all containers
rclone lsd AZStorageAccount:

# Count files per container
for container in $(rclone lsd AZStorageAccount: | awk '{print $5}'); do
    echo "Container: $container"
    rclone size AZStorageAccount:$container
done
```

### 2. Estimate Transfer Time

**Factors to consider:**
- Data size
- Network bandwidth
- Geographic distance
- File count and sizes

**Example calculation:**
```
Data Size: 1 TB = 1,000 GB
Network Speed: 100 Mbps = 12.5 MB/s
Theoretical Time: 1,000,000 MB / 12.5 MB/s = 80,000 seconds ≈ 22 hours
Actual Time (with overhead): ~30-40 hours
```

### 3. Plan Migration Windows

- Schedule during low-usage periods
- Plan for extended transfer times
- Consider incremental migrations for large datasets
- Coordinate with stakeholders

### 4. Create Migration Checklist

- [ ] Data assessment complete
- [ ] Azure Service Principal created
- [ ] AWS IAM roles configured
- [ ] Network bandwidth verified
- [ ] Test migration successful
- [ ] Backup strategy in place
- [ ] Rollback plan documented
- [ ] Stakeholders notified

## Security Best Practices

### 1. Credential Management

```bash
# Use restrictive file permissions
chmod 600 ~/.config/rclone/azure-principal.json
chmod 644 ~/.config/rclone/rclone.conf

# Never commit credentials to git
echo "azure-principal.json" >> .gitignore
echo "rclone.conf" >> .gitignore

# Use IAM roles instead of access keys for AWS
# Configure in rclone.conf:
# env_auth = true
```

### 2. Principle of Least Privilege

**Azure:**
```bash
# Use minimal required role: Storage Blob Data Reader
az ad sp create-for-rbac \
  --name rclone-azure-sp \
  --role "Storage Blob Data Reader" \
  --scopes /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<storage>
```

**AWS:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::specific-bucket",
        "arn:aws:s3:::specific-bucket/*"
      ]
    }
  ]
}
```

### 3. Network Security

```bash
# Use VPC endpoints for S3 (recommended)
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-xxxxx \
  --service-name com.amazonaws.ap-south-1.s3

# Enable encryption in transit (default in rclone)
# Both Azure and S3 use HTTPS by default

# Enable encryption at rest
# S3: Server-side encryption
# Azure: Enabled by default
```

### 4. Audit and Logging

```bash
# Enable detailed logging
rclone copy source: dest: \
  --log-file=migration-$(date +%Y%m%d-%H%M%S).log \
  --log-level INFO

# Enable S3 access logging
aws s3api put-bucket-logging \
  --bucket your-bucket \
  --bucket-logging-status file://logging.json

# Monitor with CloudWatch (AWS)
# Monitor with Azure Monitor (Azure)
```

### 5. Rotate Credentials Regularly

```bash
# Rotate Azure Service Principal password
az ad sp credential reset --id YOUR_APP_ID

# Update configuration
nano ~/.config/rclone/azure-principal.json

# Test after rotation
rclone lsd AZStorageAccount:
```

## Performance Optimization

### 1. Optimal Rclone Settings

**For Large Files (>100MB):**
```bash
rclone copy source: dest: \
  --transfers 16 \
  --checkers 8 \
  --buffer-size 256M \
  --s3-chunk-size 64M \
  --s3-upload-concurrency 16
```

**For Small Files (<10MB):**
```bash
rclone copy source: dest: \
  --transfers 64 \
  --checkers 32 \
  --buffer-size 64M \
  --fast-list
```

**For Mixed Workloads:**
```bash
rclone copy source: dest: \
  --transfers 32 \
  --checkers 16 \
  --buffer-size 128M \
  --s3-upload-concurrency 8
```

### 2. Network Optimization

```bash
# Test bandwidth
rclone test upload source: --download dest: --size 100M

# Limit bandwidth if needed (prevent network saturation)
rclone copy source: dest: --bwlimit 50M

# Use bandwidth scheduling
# Weekdays 9-5: 10MB/s, else unlimited
rclone copy source: dest: --bwlimit "09:00,10M 17:00,off"
```

### 3. Instance Sizing

**Recommended EC2 instances:**

| Data Size | Instance Type | vCPU | Memory | Network |
|-----------|---------------|------|--------|---------|
| < 100GB | t3.medium | 2 | 4GB | Up to 5 Gbps |
| 100GB - 1TB | t3.large | 2 | 8GB | Up to 5 Gbps |
| 1TB - 10TB | t3.xlarge | 4 | 16GB | Up to 5 Gbps |
| > 10TB | t3.2xlarge | 8 | 32GB | Up to 5 Gbps |

### 4. Parallel Migrations

For multiple containers:
```bash
# Create migration script for each container
for container in $(rclone lsd AZStorageAccount: | awk '{print $5}'); do
  screen -dmS "migrate-$container" bash -c "
    rclone copy AZStorageAccount:$container s3:bucket/$container \
      --progress \
      --log-file=migration-$container.log
  "
done

# Monitor all sessions
screen -ls
```

### 5. Resume Failed Transfers

```bash
# Rclone automatically resumes - just run same command
rclone copy source: dest: --progress

# For added safety, use sync with dry-run first
rclone sync source: dest: --dry-run
```

## Data Validation

### 1. Pre-Migration Validation

```bash
# Get baseline metrics
echo "Source:" > pre-migration.txt
rclone size AZStorageAccount: >> pre-migration.txt

# List all files
rclone ls AZStorageAccount: > source-files.txt
```

### 2. Post-Migration Validation

```bash
# Compare file counts and sizes
echo "Destination:" > post-migration.txt
rclone size s3:bucket >> post-migration.txt

# Generate checksum report
rclone check AZStorageAccount: s3:bucket \
  --one-way \
  --combined validation-report.txt

# Compare file lists
rclone ls s3:bucket > dest-files.txt
diff source-files.txt dest-files.txt
```

### 3. Checksum Verification

```bash
# Deep verification with checksums
rclone check AZStorageAccount: s3:bucket \
  --checksum \
  --one-way \
  -vv

# Spot check random files
RANDOM_FILES=$(rclone ls AZStorageAccount: | shuf -n 10)
for file in $RANDOM_FILES; do
  rclone check AZStorageAccount:$file s3:bucket/$file --checksum
done
```

### 4. Validation Checklist

- [ ] File counts match
- [ ] Total sizes match
- [ ] Checksum verification passed
- [ ] Sample files validated
- [ ] Directory structure verified
- [ ] Metadata preserved (if needed)
- [ ] Permissions verified (if applicable)

## Cost Optimization

### 1. Azure Egress Costs

**Minimize egress:**
- Migrate from same region as EC2 when possible
- Use Azure CDN for large transfers (if applicable)
- Batch small files together

**Azure egress pricing (example):**
- First 100 GB/month: Free
- Next 9.9 TB: ~$0.087/GB
- Next 40 TB: ~$0.083/GB

### 2. AWS S3 Storage Costs

**Choose appropriate storage class:**

```bash
# Standard (frequent access)
rclone copy source: dest: --s3-storage-class STANDARD

# Intelligent-Tiering (automatic)
rclone copy source: dest: --s3-storage-class INTELLIGENT_TIERING

# Infrequent Access
rclone copy source: dest: --s3-storage-class STANDARD_IA

# Archive
rclone copy source: dest: --s3-storage-class GLACIER
```

### 3. EC2 Cost Optimization

```bash
# Use Spot instances for non-critical migrations
aws ec2 run-instances \
  --instance-type t3.large \
  --instance-market-options MarketType=spot

# Stop instance when not in use
aws ec2 stop-instances --instance-ids i-xxxxx

# Use savings plans for long migrations
```

### 4. Data Transfer Optimization

- Compress data before transfer (if applicable)
- Use incremental sync instead of full copy
- Schedule migrations during free tier periods
- Consider AWS Direct Connect for massive transfers (>10TB)

## Operational Best Practices

### 1. Use Screen or Tmux

```bash
# Start screen session
screen -S migration

# Run migration
rclone copy source: dest: --progress

# Detach: Ctrl+A, D
# Reattach: screen -r migration

# List sessions
screen -ls
```

### 2. Monitoring and Alerting

```bash
# Monitor progress in real-time
watch -n 60 'rclone size s3:bucket'

# Create monitoring script
cat > monitor.sh <<'EOF'
#!/bin/bash
while true; do
  echo "$(date): $(rclone size s3:bucket | grep 'Total size')" >> progress.log
  sleep 300  # Check every 5 minutes
done
EOF
chmod +x monitor.sh
./monitor.sh &
```

### 3. Documentation

**Document everything:**
- Source and destination details
- Service principal information
- IAM roles and policies
- Migration timeline
- Issues encountered and resolutions
- Validation results

### 4. Incremental Migrations

```bash
# Initial migration
rclone copy source: dest: --progress

# Incremental sync (copies only new/changed files)
rclone sync source: dest: --progress

# Or use copy with --update
rclone copy source: dest: --update --progress
```

### 5. Backup Strategy

**Before deleting source:**
- Keep Azure data for 30-90 days
- Verify all applications work with S3
- Document rollback procedure
- Create snapshots if possible

```bash
# Enable S3 versioning
aws s3api put-bucket-versioning \
  --bucket your-bucket \
  --versioning-configuration Status=Enabled

# Create lifecycle policy for old versions
aws s3api put-bucket-lifecycle-configuration \
  --bucket your-bucket \
  --lifecycle-configuration file://lifecycle.json
```

### 6. Communication

**Keep stakeholders informed:**
- Send pre-migration notice
- Provide progress updates
- Report completion with validation results
- Document any issues or deviations

## Migration Workflow Example

```bash
# 1. Pre-migration
./scripts/pre-check.sh
rclone size AZStorageAccount: > baseline.txt

# 2. Test migration
rclone copy AZStorageAccount:test-container s3:test-bucket --dry-run

# 3. Actual migration
screen -S migration
./scripts/migrate.sh AZStorageAccount: s3:production-bucket

# 4. Validation
./scripts/verify.sh AZStorageAccount: s3:production-bucket

# 5. Post-migration
./scripts/post-check.sh
rclone size s3:production-bucket > final.txt

# 6. Documentation
echo "Migration completed: $(date)" >> migration-log.txt
```

## Common Pitfalls to Avoid

1. **Not testing before production migration**
   - Always run dry-run first
   - Test with small dataset

2. **Insufficient permissions**
   - Verify permissions before starting
   - Use least privilege principle

3. **Not monitoring progress**
   - Use --progress flag
   - Set up monitoring scripts

4. **Ignoring validation**
   - Always verify after migration
   - Use checksum verification

5. **Deleting source too quickly**
   - Keep source for validation period
   - Verify all applications work

6. **Not documenting the process**
   - Keep detailed logs
   - Document issues and solutions

## Summary Checklist

- [ ] Plan and assess data
- [ ] Configure security properly
- [ ] Optimize for performance
- [ ] Test thoroughly
- [ ] Monitor during migration
- [ ] Validate completely
- [ ] Document everything
- [ ] Keep backups temporarily
- [ ] Communicate with stakeholders
- [ ] Review and improve process

## Resources

- [Rclone Documentation](https://rclone.org/docs/)
- [Azure Storage Best Practices](https://docs.microsoft.com/azure/storage/common/storage-performance-checklist)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/best-practices.html)
- [AWS Data Transfer Options](https://aws.amazon.com/cloud-data-migration/)
