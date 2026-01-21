#!/bin/bash
# Azure CLI Commands for Service Principal Setup

# Login to Azure
az login

# List subscriptions
az account list --output table

# Set active subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# List resource groups
az group list --output table

# List storage accounts in a resource group
az storage account list --resource-group YOUR_RESOURCE_GROUP --output table

# Get storage account details
az storage account show \
  --name YOUR_STORAGE_ACCOUNT \
  --resource-group YOUR_RESOURCE_GROUP

# Get storage account resource ID
STORAGE_ID=$(az storage account show \
  --name YOUR_STORAGE_ACCOUNT \
  --resource-group YOUR_RESOURCE_GROUP \
  --query id \
  --output tsv)

echo "Storage Account ID: $STORAGE_ID"

# Create Service Principal with Storage Blob Data Reader role
echo "Creating Service Principal..."
az ad sp create-for-rbac \
  --name "rclone-azure-sp" \
  --role "Storage Blob Data Reader" \
  --scopes "$STORAGE_ID" \
  --output json

# List Service Principals
az ad sp list --display-name "rclone-azure-sp" --output table

# Get Service Principal details
APP_ID="YOUR_APP_ID_FROM_ABOVE"
az ad sp show --id "$APP_ID"

# List role assignments for Service Principal
az role assignment list --assignee "$APP_ID" --all --output table

# Test Azure Storage access (requires login)
az storage blob list \
  --account-name YOUR_STORAGE_ACCOUNT \
  --container-name YOUR_CONTAINER \
  --auth-mode login \
  --output table

# Optional: Create new Service Principal password
# az ad sp credential reset --id "$APP_ID"

# Optional: Delete Service Principal (cleanup)
# az ad sp delete --id "$APP_ID"

# Optional: List available roles
az role definition list --query "[?contains(roleName, 'Storage')].{Name:roleName, Description:description}" --output table
