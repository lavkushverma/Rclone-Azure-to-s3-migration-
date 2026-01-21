# Quick Reference Guide

Quick command reference for Azure to S3 migration using rclone.

## Installation

```bash
# Install rclone
sudo -v
curl https://rclone.org/install.sh | sudo bash
```

## Azure Service Principal

```bash
# Create Service Principal
az ad sp create-for-rbac \
  --name rclone-azure-sp \
  --role "Storage Blob Data Reader" \
  --scopes /subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Storage/storageAccounts/<STORAGE>
```

## Configuration Files

### ~/.config/rclone/azure-principal.json
```json
{
  "appId": "YOUR_APP_ID",
  "password": "YOUR_PASSWORD",
  "tenant": "YOUR_TENANT_ID"
}
```

### ~/.config/rclone/rclone.conf
```ini
[AZStorageAccount]
type = azureblob
account = your-storage-name
service_principal_file = /home/ec2-user/.config/rclone/azure-principal.json

[s3]
type = s3
provider = AWS
env_auth = true
region = ap-south-1
```

## Common Commands

### List Remotes
```bash
rclone listremotes
```

### List Containers/Buckets
```bash
rclone lsd AZStorageAccount:
rclone lsd s3:
```

### Check Size
```bash
rclone size AZStorageAccount:
rclone size AZStorageAccount:container
rclone size s3:bucket
```

### List Files
```bash
rclone ls AZStorageAccount:container
rclone ls s3:bucket
```

### Copy (Recommended)
```bash
# Copy all
rclone copy AZStorageAccount: s3:bucket --progress

# Copy specific container
rclone copy AZStorageAccount:container s3:bucket --progress

# Copy with options
rclone copy AZStorageAccount: s3:bucket \
  --progress \
  --transfers 32 \
  --checkers 16 \
  --log-file=migration.log
```

### Sync (Use with caution)
```bash
# Dry run first
rclone sync AZStorageAccount: s3:bucket --dry-run

# Actual sync (deletes files not in source)
rclone sync AZStorageAccount: s3:bucket --progress
```

### Verify Migration
```bash
# Check for differences
rclone check AZStorageAccount:container s3:bucket --one-way

# With checksum
rclone check AZStorageAccount:container s3:bucket --checksum --one-way

# Generate report
rclone check AZStorageAccount: s3:bucket --one-way --combined report.txt
```

## Optimized Settings

### Large Files (>100MB)
```bash
rclone copy source: dest: \
  --transfers 16 \
  --checkers 8 \
  --buffer-size 256M \
  --s3-chunk-size 64M \
  --s3-upload-concurrency 16 \
  --progress
```

### Small Files (<10MB)
```bash
rclone copy source: dest: \
  --transfers 64 \
  --checkers 32 \
  --buffer-size 64M \
  --fast-list \
  --progress
```

### Mixed Workload
```bash
rclone copy source: dest: \
  --transfers 32 \
  --checkers 16 \
  --buffer-size 128M \
  --s3-upload-concurrency 8 \
  --progress
```

## Useful Flags

| Flag | Description |
|------|-------------|
| `--progress` | Show progress |
| `--dry-run` | Test without copying |
| `--update` | Skip files that are newer on dest |
| `--checksum` | Verify checksums |
| `--log-file=FILE` | Log to file |
| `--log-level INFO` | Set log level |
| `--stats 1m` | Show stats every minute |
| `--bwlimit 10M` | Limit bandwidth to 10MB/s |
| `-v` | Verbose |
| `-vv` | Very verbose |

## Screen/Tmux

### Screen
```bash
# Start session
screen -S migration

# Detach: Ctrl+A, D

# List sessions
screen -ls

# Reattach
screen -r migration

# Kill session
screen -X -S migration quit
```

### Tmux
```bash
# Start session
tmux new -s migration

# Detach: Ctrl+B, D

# List sessions
tmux ls

# Reattach
tmux attach -t migration

# Kill session
tmux kill-session -t migration
```

## Troubleshooting

### Test Azure Connection
```bash
rclone lsd AZStorageAccount: -vv
```

### Test S3 Connection
```bash
rclone lsd s3: -vv
```

### Check AWS Credentials
```bash
aws sts get-caller-identity
```

### View Logs
```bash
tail -f migration.log
less migration.log
```

## AWS CLI

### List Buckets
```bash
aws s3 ls
```

### Check Bucket Size
```bash
aws s3 ls s3://bucket --recursive --summarize --human-readable
```

### Create Bucket
```bash
aws s3 mb s3://bucket --region ap-south-1
```

## Azure CLI

### List Storage Accounts
```bash
az storage account list --output table
```

### List Containers
```bash
az storage container list --account-name STORAGE --output table
```

### List Service Principals
```bash
az ad sp list --display-name rclone-azure-sp
```

## Quick Migration Workflow

```bash
# 1. Install rclone
curl https://rclone.org/install.sh | sudo bash

# 2. Run setup script
./scripts/setup.sh

# 3. Verify configuration
rclone listremotes
rclone lsd AZStorageAccount:
rclone lsd s3:

# 4. Dry run
rclone copy AZStorageAccount: s3:bucket --dry-run

# 5. Start migration
screen -S migration
rclone copy AZStorageAccount: s3:bucket --progress

# 6. Verify
./scripts/verify.sh AZStorageAccount: s3:bucket
```

## Emergency Stop

```bash
# Press Ctrl+C to stop rclone gracefully

# Force kill (if needed)
pkill -9 rclone
```

## Cleanup

```bash
# Remove old logs
find . -name "*.log" -mtime +7 -delete

# Clear rclone cache
rm -rf ~/.cache/rclone/
```

## Important Notes

- Always test with `--dry-run` first
- Use `--progress` to monitor
- Keep Azure data until verified
- Check file counts and sizes
- Use checksums for validation
- Monitor disk space on EC2
- Use screen/tmux for long transfers

## Support

- Documentation: `docs/`
- Troubleshooting: `docs/TROUBLESHOOTING.md`
- Best Practices: `docs/BEST_PRACTICES.md`
- Issues: GitHub Issues
