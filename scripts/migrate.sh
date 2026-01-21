#!/bin/bash

# Migration Monitoring Script
# Monitors ongoing migration and provides real-time statistics

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}$1${NC}"; }
print_success() { echo -e "${GREEN}$1${NC}"; }

# Check arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <azure-source> <s3-destination> [options]"
    echo ""
    echo "Examples:"
    echo "  $0 AZStorageAccount:container s3:bucket"
    echo "  $0 AZStorageAccount: s3:bucket --transfers 32"
    exit 1
fi

SOURCE="$1"
DEST="$2"
shift 2
EXTRA_OPTS="$@"

LOG_FILE="migration-$(date +%Y%m%d-%H%M%S).log"

print_info "Starting migration with monitoring..."
echo "Source: $SOURCE"
echo "Destination: $DEST"
echo "Log file: $LOG_FILE"
echo ""
echo "Press Ctrl+C to cancel (migration will stop gracefully)"
echo "Starting in 5 seconds..."
sleep 5

# Run migration with optimal settings
rclone copy "$SOURCE" "$DEST" \
  --progress \
  --stats 1m \
  --stats-one-line \
  --transfers 32 \
  --checkers 16 \
  --buffer-size 256M \
  --s3-upload-concurrency 16 \
  --log-file="$LOG_FILE" \
  --log-level INFO \
  $EXTRA_OPTS

echo ""
print_success "Migration completed!"
echo ""
echo "Summary:"
echo "  Log file: $LOG_FILE"
echo ""
echo "Next steps:"
echo "  1. Verify migration: ./scripts/verify.sh $SOURCE $DEST"
echo "  2. Review log file: less $LOG_FILE"
