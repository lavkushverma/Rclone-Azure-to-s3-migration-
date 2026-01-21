#!/bin/bash
# AWS CLI Commands for S3 and IAM Setup

# Check AWS CLI version
aws --version

# Get current identity
aws sts get-caller-identity

# List S3 buckets
aws s3 ls

# Create S3 bucket
BUCKET_NAME="your-migration-bucket"
REGION="ap-south-1"

aws s3 mb "s3://$BUCKET_NAME" --region "$REGION"

# Enable versioning on bucket
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

# Create IAM policy for S3 access
POLICY_NAME="RcloneS3MigrationPolicy"

aws iam create-policy \
  --policy-name "$POLICY_NAME" \
  --policy-document file://examples/iam-policy.json

# Create IAM role for EC2
ROLE_NAME="rclone-s3-migration-role"

# Create trust policy
cat > /tmp/trust-policy.json <<EOF
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

aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust-policy.json

# Attach policy to role
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME"

aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn "$POLICY_ARN"

# Create instance profile
PROFILE_NAME="rclone-s3-migration-profile"

aws iam create-instance-profile \
  --instance-profile-name "$PROFILE_NAME"

# Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --role-name "$ROLE_NAME"

# Wait for instance profile to be ready
sleep 10

echo "Instance Profile ARN:"
aws iam get-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --query 'InstanceProfile.Arn' \
  --output text

# Attach instance profile to EC2 instance
# INSTANCE_ID="i-xxxxxxxxxxxx"
# aws ec2 associate-iam-instance-profile \
#   --instance-id "$INSTANCE_ID" \
#   --iam-instance-profile "Name=$PROFILE_NAME"

# Verify IAM role on EC2 (run this on the EC2 instance)
# aws sts get-caller-identity

# List bucket contents
aws s3 ls "s3://$BUCKET_NAME/"

# Set lifecycle policy (optional - for cost optimization)
cat > /tmp/lifecycle.json <<EOF
{
  "Rules": [
    {
      "Id": "DeleteOldVersions",
      "Status": "Enabled",
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 90
      }
    },
    {
      "Id": "TransitionToIA",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        }
      ]
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET_NAME" \
  --lifecycle-configuration file:///tmp/lifecycle.json

# Enable access logging (optional)
LOGGING_BUCKET="$BUCKET_NAME-logs"
aws s3 mb "s3://$LOGGING_BUCKET" --region "$REGION"

cat > /tmp/logging.json <<EOF
{
  "LoggingEnabled": {
    "TargetBucket": "$LOGGING_BUCKET",
    "TargetPrefix": "s3-access-logs/"
  }
}
EOF

aws s3api put-bucket-logging \
  --bucket "$BUCKET_NAME" \
  --bucket-logging-status file:///tmp/logging.json

# Cleanup temporary files
rm -f /tmp/trust-policy.json /tmp/lifecycle.json /tmp/logging.json

echo "Setup complete!"
echo "Bucket: $BUCKET_NAME"
echo "IAM Role: $ROLE_NAME"
echo "Instance Profile: $PROFILE_NAME"
