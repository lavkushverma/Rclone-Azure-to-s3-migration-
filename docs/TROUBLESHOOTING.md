# Troubleshooting Guide

Common issues and solutions for Azure to S3 migration using rclone.

## Table of Contents

1. [Authentication Issues](#authentication-issues)
2. [Connection Problems](#connection-problems)
3. [Performance Issues](#performance-issues)
4. [File Transfer Errors](#file-transfer-errors)
5. [Configuration Issues](#configuration-issues)

## Authentication Issues

### Azure: "Failed to create file system: failed to make azure storage URL"

**Cause:** Incorrect storage account name or authentication failure

**Solutions:**

```bash
# 1. Verify storage account name
az storage account list --query "[].name" --output table

# 2. Check service principal JSON format
cat ~/.config/rclone/azure-principal.json
# Should be valid JSON with appId, password, tenant

# 3. Verify service principal exists
az ad sp show --id YOUR_APP_ID

# 4. Check role assignments
az role assignment list --assignee YOUR_APP_ID --all

# 5. Test with verbose logging
rclone lsd AZStorageAccount: -vv 2>&1 | tee azure-debug.log
```

### Azure: "Service principal not found"

**Cause:** Service principal doesn't exist or wrong tenant

**Solutions:**

```bash
# List all service principals
az ad sp list --all --query "[?displayName=='rclone-azure-sp']"

# Recreate service principal
STORAGE_ID=$(az storage account show \
  --name YOUR_STORAGE \
  --resource-group YOUR_RG \
  --query id --output tsv)

az ad sp create-for-rbac \
  --name rclone-azure-sp-new \
  --role "Storage Blob Data Reader" \
  --scopes $STORAGE_ID
```

### AWS: "NoCredentialProviders: no valid providers in chain"

**Cause:** IAM role not attached or AWS credentials not configured

**Solutions:**

```bash
# 1. Check if IAM role is attached
aws sts get-caller-identity

# 2. Check instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/

# 3. Verify IAM role has S3 permissions
aws iam get-role-policy \
  --role-name YOUR_ROLE_NAME \
  --policy-name YOUR_POLICY_NAME

# 4. Test S3 access directly
aws s3 ls s3://your-bucket/
```

### AWS: "AccessDenied: Access Denied"

**Cause:** IAM role lacks necessary S3 permissions

**Solutions:**

```bash
# Check current permissions
aws iam list-attached-role-policies --role-name YOUR_ROLE

# Required permissions for migration:
cat > s3-permissions.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket",
        "arn:aws:s3:::your-bucket/*"
      ]
    }
  ]
}
EOF

# Update IAM policy
aws iam put-role-policy \
  --role-name YOUR_ROLE \
  --policy-name S3AccessPolicy \
  --policy-document file://s3-permissions.json
```

## Connection Problems

### "dial tcp: lookup xxx: no such host"

**Cause:** DNS resolution failure

**Solutions:**

```bash
# 1. Check DNS configuration
cat /etc/resolv.conf

# 2. Test DNS resolution
nslookup your-storage.blob.core.windows.net
nslookup s3.ap-south-1.amazonaws.com

# 3. Update DNS (if needed)
sudo bash -c 'echo "nameserver 8.8.8.8" >> /etc/resolv.conf'
sudo bash -c 'echo "nameserver 8.8.4.4" >> /etc/resolv.conf'

# 4. Test connectivity
curl -I https://your-storage.blob.core.windows.net
curl -I https://s3.ap-south-1.amazonaws.com
```

### "connection timeout" or "i/o timeout"

**Cause:** Network connectivity issues or firewall blocking

**Solutions:**

```bash
# 1. Check security group allows outbound HTTPS (port 443)
aws ec2 describe-security-groups --group-ids sg-xxxxx

# 2. Test outbound connectivity
telnet your-storage.blob.core.windows.net 443
telnet s3.ap-south-1.amazonaws.com 443

# 3. Check routing
traceroute your-storage.blob.core.windows.net

# 4. Increase timeout in rclone
rclone copy source: dest: --timeout 5m
```

### "TLS handshake timeout"

**Cause:** SSL/TLS issues or very slow connection

**Solutions:**

```bash
# 1. Update CA certificates
sudo yum update ca-certificates -y  # Amazon Linux
sudo apt update && sudo apt install ca-certificates -y  # Ubuntu

# 2. Test SSL connection
openssl s_client -connect your-storage.blob.core.windows.net:443

# 3. Use different timeout settings
rclone copy source: dest: \
  --contimeout 60s \
  --timeout 300s \
  --low-level-retries 10
```

## Performance Issues

### Slow Transfer Speeds

**Cause:** Default rclone settings not optimized for large transfers

**Solutions:**

```bash
# Optimize rclone settings
rclone copy source: dest: \
  --transfers 32 \          # Increase parallel transfers
  --checkers 16 \           # Increase parallel checkers
  --buffer-size 256M \      # Increase buffer size
  --s3-upload-concurrency 16 \  # Parallel S3 uploads
  --s3-chunk-size 64M \     # Larger chunk size
  --progress

# Monitor system resources
top
iostat -x 1
iftop  # Network monitoring
```

### High Memory Usage

**Cause:** Too many parallel transfers or large buffer sizes

**Solutions:**

```bash
# Reduce parallelism
rclone copy source: dest: \
  --transfers 8 \
  --checkers 8 \
  --buffer-size 64M

# Monitor memory
free -h
watch -n 1 free -h
```

### CPU Bottleneck

**Cause:** Compression or encryption overhead

**Solutions:**

```bash
# Disable unnecessary features
rclone copy source: dest: \
  --s3-no-check-bucket \
  --no-traverse \
  --fast-list

# Use larger instance type if needed
# Consider: t3.xlarge (4 vCPU, 16 GB RAM)
```

## File Transfer Errors

### "Failed to copy: file already exists"

**Cause:** Destination file exists and rclone is configured to not overwrite

**Solutions:**

```bash
# Skip existing files (default behavior)
rclone copy source: dest:

# Update existing files if source is newer
rclone copy source: dest: --update

# Overwrite all files
rclone copy source: dest: --ignore-existing=false
```

### "Insufficient storage"

**Cause:** EC2 instance running out of disk space

**Solutions:**

```bash
# Check disk space
df -h

# Clean up logs
find . -name "*.log" -mtime +7 -delete

# Increase EBS volume size
aws ec2 modify-volume --volume-id vol-xxxxx --size 100

# Extend filesystem
sudo growpart /dev/xvda 1
sudo resize2fs /dev/xvda1
```

### "File name too long"

**Cause:** File path exceeds OS limits

**Solutions:**

```bash
# List long filenames
rclone ls source: | awk '{print length, $0}' | sort -nr | head -20

# Use shorter destination paths
rclone copy source:long/path dest:short/

# Enable long path support (Linux)
getconf PATH_MAX /
```

### Checksum Mismatch Errors

**Cause:** File corruption during transfer

**Solutions:**

```bash
# Retry with checksum verification
rclone copy source: dest: \
  --checksum \
  --check-first \
  --low-level-retries 10

# Use different hash algorithm
rclone copy source: dest: \
  --s3-upload-cutoff 200M \
  --s3-chunk-size 50M

# Check individual file
rclone check source:file dest:file -vv
```

## Configuration Issues

### "Failed to load config file"

**Cause:** Invalid configuration file syntax

**Solutions:**

```bash
# Validate config file
rclone config show

# Check file permissions
ls -la ~/.config/rclone/rclone.conf

# Recreate configuration
mv ~/.config/rclone/rclone.conf ~/.config/rclone/rclone.conf.bak
nano ~/.config/rclone/rclone.conf
```

### "Remote not found"

**Cause:** Remote name in command doesn't match configuration

**Solutions:**

```bash
# List available remotes
rclone listremotes

# Check exact remote name (case-sensitive)
rclone config show

# Use correct remote name
rclone lsd AZStorageAccount:  # Must match config [AZStorageAccount]
```

### Incorrect File Paths

**Cause:** Wrong path to azure-principal.json in config

**Solutions:**

```bash
# Find current user's home directory
echo $HOME

# Update rclone.conf with absolute path
nano ~/.config/rclone/rclone.conf

# Verify file exists
ls -la ~/.config/rclone/azure-principal.json

# Test with explicit path
rclone lsd AZStorageAccount: -vv
```

## Advanced Debugging

### Enable Maximum Logging

```bash
# Create debug log
rclone copy source: dest: \
  -vv \
  --log-file=rclone-debug.log \
  --log-level DEBUG

# Watch log in real-time
tail -f rclone-debug.log
```

### Test Individual Components

```bash
# Test Azure only
rclone lsd AZStorageAccount: -vv

# Test S3 only
rclone lsd s3: -vv

# Test single file transfer
rclone copy AZStorageAccount:container/test.txt /tmp/test.txt -vv
```

### Network Diagnostics

```bash
# Test bandwidth
rclone test upload source: --download dest: --size 100M

# Check latency
ping -c 10 your-storage.blob.core.windows.net
ping -c 10 s3.ap-south-1.amazonaws.com

# Monitor network traffic
sudo tcpdump -i eth0 port 443 -w capture.pcap
```

## Getting Help

If you're still experiencing issues:

1. Check rclone logs: `cat rclone-debug.log`
2. Review [Rclone Forum](https://forum.rclone.org/)
3. Check [Rclone GitHub Issues](https://github.com/rclone/rclone/issues)
4. Provide full error message and rclone command used
5. Include relevant configuration (remove sensitive data)

## Common Error Messages Quick Reference

| Error | Likely Cause | Quick Fix |
|-------|--------------|-----------|
| `404 Not Found` | Wrong container/bucket name | Verify names with `lsd` |
| `403 Forbidden` | Insufficient permissions | Check IAM/RBAC roles |
| `401 Unauthorized` | Invalid credentials | Verify Service Principal |
| `Connection refused` | Port blocked | Check security groups |
| `Timeout` | Network issue | Increase timeout values |
| `Out of memory` | Too many transfers | Reduce --transfers |
| `Disk full` | No space left | Increase EBS volume |

## Best Practices to Avoid Issues

1. **Always test with dry-run first**
   ```bash
   rclone copy source: dest: --dry-run
   ```

2. **Start with small data set**
   ```bash
   rclone copy source:container/small-folder dest:
   ```

3. **Use progress and stats**
   ```bash
   rclone copy source: dest: --progress --stats 1m
   ```

4. **Keep logs for troubleshooting**
   ```bash
   rclone copy source: dest: --log-file=migration.log
   ```

5. **Monitor system resources**
   ```bash
   watch -n 1 'free -h && df -h'
   ```
