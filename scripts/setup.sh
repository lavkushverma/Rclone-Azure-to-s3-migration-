#!/bin/bash

# Azure to S3 Migration Setup Script
# This script automates the setup of rclone for migrating data from Azure Blob Storage to AWS S3

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_header() {
    echo ""
    echo "================================"
    echo "$1"
    echo "================================"
    echo ""
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    print_error "Please do not run this script as root"
    exit 1
fi

print_header "Azure to S3 Migration Setup"

# Step 1: Install rclone
print_info "Step 1: Installing rclone..."
if command -v rclone &> /dev/null; then
    print_success "rclone is already installed ($(rclone version | head -n1))"
else
    print_info "Installing rclone..."
    sudo -v
    curl -s https://rclone.org/install.sh | sudo bash
    print_success "rclone installed successfully"
fi

# Step 2: Create config directory
print_info "Step 2: Creating rclone configuration directory..."
mkdir -p ~/.config/rclone
print_success "Configuration directory created"

# Step 3: Azure Service Principal Configuration
print_header "Azure Configuration"
print_info "You need to create an Azure Service Principal first."
echo ""
echo "Run this command in Azure CLI (on your local machine or Azure Cloud Shell):"
echo ""
echo "az ad sp create-for-rbac \\"
echo "  --name rclone-azure-sp \\"
echo "  --role \"Storage Blob Data Reader\" \\"
echo "  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.Storage/storageAccounts/<STORAGE_ACCOUNT_NAME>"
echo ""

read -p "Have you created the Service Principal? (y/n): " sp_created

if [[ $sp_created =~ ^[Yy]$ ]]; then
    echo ""
    print_info "Please enter your Azure Service Principal details:"
    read -p "Enter appId: " app_id
    read -p "Enter tenant: " tenant_id
    read -sp "Enter password (hidden): " password
    echo ""
    read -p "Enter Azure Storage Account name: " storage_account
    
    # Create azure-principal.json
    cat > ~/.config/rclone/azure-principal.json <<EOF
{
  "appId": "$app_id",
  "password": "$password",
  "tenant": "$tenant_id"
}
EOF
    
    chmod 600 ~/.config/rclone/azure-principal.json
    print_success "Azure Service Principal configuration saved"
else
    print_error "Please create the Service Principal first and run this script again"
    exit 1
fi

# Step 4: AWS Configuration
print_header "AWS Configuration"
read -p "Enter AWS region (e.g., ap-south-1): " aws_region
read -p "Enter S3 bucket name: " s3_bucket

# Check if AWS credentials are available
if aws sts get-caller-identity &> /dev/null; then
    print_success "AWS credentials are configured"
elif [ -f ~/.aws/credentials ] || [ ! -z "$AWS_ACCESS_KEY_ID" ]; then
    print_success "AWS credentials found"
else
    print_info "No AWS credentials found. Make sure your EC2 instance has an IAM role attached."
fi

# Step 5: Create rclone.conf
print_info "Step 5: Creating rclone configuration file..."

PRINCIPAL_PATH="$HOME/.config/rclone/azure-principal.json"

cat > ~/.config/rclone/rclone.conf <<EOF
[AZStorageAccount]
type = azureblob
account = $storage_account
service_principal_file = $PRINCIPAL_PATH

[s3]
type = s3
provider = AWS
env_auth = true
region = $aws_region
EOF

chmod 644 ~/.config/rclone/rclone.conf
print_success "Rclone configuration created"

# Step 6: Verify configuration
print_header "Verification"
print_info "Testing rclone configuration..."

echo ""
echo "Available remotes:"
rclone listremotes

echo ""
print_info "Testing Azure connection..."
if rclone lsd AZStorageAccount: 2>&1 | grep -q "Failed"; then
    print_error "Azure connection failed. Please check your configuration."
else
    print_success "Azure connection successful"
    echo ""
    echo "Azure containers:"
    rclone lsd AZStorageAccount:
fi

echo ""
print_info "Testing AWS S3 connection..."
if rclone lsd s3: 2>&1 | grep -q "Failed"; then
    print_error "S3 connection failed. Please check your IAM role/credentials."
else
    print_success "S3 connection successful"
    echo ""
    echo "S3 buckets:"
    rclone lsd s3:
fi

# Step 7: Summary and next steps
print_header "Setup Complete!"
echo ""
echo "Configuration files created:"
echo "  • ~/.config/rclone/rclone.conf"
echo "  • ~/.config/rclone/azure-principal.json"
echo ""
echo "Next steps:"
echo "  1. Verify your configuration: rclone config show"
echo "  2. Check storage sizes:"
echo "     • Azure: rclone size AZStorageAccount:"
echo "     • S3: rclone size s3:$s3_bucket"
echo "  3. Run a dry-run migration:"
echo "     rclone copy AZStorageAccount: s3:$s3_bucket --dry-run --progress"
echo "  4. Execute actual migration:"
echo "     rclone copy AZStorageAccount: s3:$s3_bucket --progress"
echo ""
print_success "You're ready to start migrating!"
echo ""

# Create a migration script
cat > ~/migrate.sh <<'MIGRATE_EOF'
#!/bin/bash

# Simple migration script
# Usage: ./migrate.sh [source] [destination]

set -e

SOURCE="${1:-AZStorageAccount:}"
DEST="${2:-s3:}"

echo "Starting migration from $SOURCE to $DEST"
echo "Press Ctrl+C to cancel in the next 5 seconds..."
sleep 5

rclone copy "$SOURCE" "$DEST" \
  --progress \
  --transfers 32 \
  --checkers 16 \
  --log-file=migration-$(date +%Y%m%d-%H%M%S).log \
  --log-level INFO \
  --stats 1m

echo "Migration complete!"
echo "Check the log file for details."
MIGRATE_EOF

chmod +x ~/migrate.sh
print_success "Migration script created: ~/migrate.sh"
