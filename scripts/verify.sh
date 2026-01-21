#!/bin/bash

# Migration Verification Script
# Verifies data integrity after migration from Azure to S3

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
    echo ""
}

# Check arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <azure-source> <s3-destination>"
    echo ""
    echo "Examples:"
    echo "  $0 AZStorageAccount:container-name s3:bucket-name"
    echo "  $0 AZStorageAccount: s3:bucket-name"
    exit 1
fi

SOURCE="$1"
DEST="$2"

print_header "Migration Verification Tool"
echo "Source: $SOURCE"
echo "Destination: $DEST"
echo ""

# Step 1: Check if remotes exist
print_info "Step 1: Verifying remotes..."
if ! rclone listremotes | grep -q "$(echo $SOURCE | cut -d: -f1):"; then
    print_error "Source remote not found"
    exit 1
fi

if ! rclone listremotes | grep -q "$(echo $DEST | cut -d: -f1):"; then
    print_error "Destination remote not found"
    exit 1
fi
print_success "Remotes verified"

# Step 2: Get file counts and sizes
print_info "Step 2: Analyzing source storage..."
echo "This may take a while for large datasets..."
SOURCE_INFO=$(rclone size "$SOURCE" 2>&1)
if [ $? -eq 0 ]; then
    echo "$SOURCE_INFO"
    SOURCE_COUNT=$(echo "$SOURCE_INFO" | grep "Total objects:" | awk '{print $3}')
    SOURCE_SIZE=$(echo "$SOURCE_INFO" | grep "Total size:" | awk '{print $3, $4}')
    print_success "Source analysis complete"
else
    print_error "Failed to analyze source"
    exit 1
fi

print_info "Step 3: Analyzing destination storage..."
DEST_INFO=$(rclone size "$DEST" 2>&1)
if [ $? -eq 0 ]; then
    echo "$DEST_INFO"
    DEST_COUNT=$(echo "$DEST_INFO" | grep "Total objects:" | awk '{print $3}')
    DEST_SIZE=$(echo "$DEST_INFO" | grep "Total size:" | awk '{print $3, $4}')
    print_success "Destination analysis complete"
else
    print_error "Failed to analyze destination"
    exit 1
fi

# Step 3: Compare counts
print_header "Comparison Results"
echo "Source:"
echo "  Files: $SOURCE_COUNT"
echo "  Size: $SOURCE_SIZE"
echo ""
echo "Destination:"
echo "  Files: $DEST_COUNT"
echo "  Size: $DEST_SIZE"
echo ""

if [ "$SOURCE_COUNT" -eq "$DEST_COUNT" ]; then
    print_success "File counts match!"
else
    print_warning "File counts differ!"
    echo "  Difference: $((SOURCE_COUNT - DEST_COUNT)) files"
fi

# Step 4: Detailed verification
print_info "Step 4: Running detailed verification (this may take a while)..."
CHECK_LOG="verification-$(date +%Y%m%d-%H%M%S).log"

echo "Checking for missing or different files..."
rclone check "$SOURCE" "$DEST" --one-way --combined "$CHECK_LOG" 2>&1

if [ $? -eq 0 ]; then
    print_success "Verification complete - All files match!"
else
    print_warning "Differences found. Check log: $CHECK_LOG"
    
    if [ -f "$CHECK_LOG" ]; then
        MISSING=$(grep -c "MISSING" "$CHECK_LOG" 2>/dev/null || echo "0")
        DIFFER=$(grep -c "DIFFER" "$CHECK_LOG" 2>/dev/null || echo "0")
        
        echo ""
        echo "Summary:"
        echo "  Missing files: $MISSING"
        echo "  Different files: $DIFFER"
        echo ""
        
        if [ "$MISSING" -gt 0 ]; then
            print_warning "Some files are missing in destination"
            echo "First 10 missing files:"
            grep "MISSING" "$CHECK_LOG" | head -n 10
        fi
        
        if [ "$DIFFER" -gt 0 ]; then
            print_warning "Some files differ between source and destination"
            echo "First 10 different files:"
            grep "DIFFER" "$CHECK_LOG" | head -n 10
        fi
    fi
fi

# Step 5: Generate report
print_header "Verification Report"
REPORT_FILE="verification-report-$(date +%Y%m%d-%H%M%S).txt"

cat > "$REPORT_FILE" <<EOF
Migration Verification Report
Generated: $(date)

Source: $SOURCE
Destination: $DEST

Source Statistics:
  Total Files: $SOURCE_COUNT
  Total Size: $SOURCE_SIZE

Destination Statistics:
  Total Files: $DEST_COUNT
  Total Size: $DEST_SIZE

Status: $([ "$SOURCE_COUNT" -eq "$DEST_COUNT" ] && echo "PASS" || echo "NEEDS REVIEW")

Detailed Log: $CHECK_LOG
EOF

print_success "Report generated: $REPORT_FILE"
echo ""

# Step 6: Recommendations
print_header "Recommendations"

if [ "$SOURCE_COUNT" -eq "$DEST_COUNT" ]; then
    echo "✓ Migration appears successful"
    echo "✓ All file counts match"
    echo ""
    echo "Next steps:"
    echo "  1. Review the detailed log: $CHECK_LOG"
    echo "  2. Perform application-level testing"
    echo "  3. Keep Azure data for backup until fully validated"
else
    echo "⚠ Migration needs attention"
    echo ""
    echo "Next steps:"
    echo "  1. Review missing/different files in: $CHECK_LOG"
    echo "  2. Re-run migration for missing files:"
    echo "     rclone copy $SOURCE $DEST --progress"
    echo "  3. Run this verification script again"
fi

echo ""
print_info "Verification complete!"
