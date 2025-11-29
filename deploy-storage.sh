#!/bin/bash

# Azure Data Obfuscator - Bash Deployment Script (Blob Storage)
# This script deploys the Data Obfuscator to Azure Blob Storage Static Website

set -e  # Exit on error

# Default parameters
RESOURCE_GROUP_NAME="${1:-rg-data-obfuscator}"
STORAGE_ACCOUNT_NAME="${2}"
LOCATION="${3:-westeurope}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================"
echo -e "Data Obfuscator Azure Deployment"
echo -e "   (Blob Storage Static Website)"
echo -e "========================================${NC}"
echo ""

# Generate unique storage account name if not provided
if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
    RANDOM_SUFFIX=$((RANDOM % 9999))
    STORAGE_ACCOUNT_NAME="dataobfuscator${RANDOM_SUFFIX}"
    echo -e "${CYAN}Generated storage account name: $STORAGE_ACCOUNT_NAME${NC}"
fi

# Validate storage account name
if ! [[ "$STORAGE_ACCOUNT_NAME" =~ ^[a-z0-9]{3,24}$ ]]; then
    echo -e "${RED}X Storage account name must be 3-24 characters, lowercase letters and numbers only${NC}"
    exit 1
fi

# Check if Azure CLI is installed
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command -v az &> /dev/null; then
    echo -e "${RED}X Azure CLI is not installed!${NC}"
    echo -e "${YELLOW}  Please install from: https://aka.ms/installazurecli${NC}"
    exit 1
fi

AZ_VERSION=$(az version --query '\"azure-cli\"' -o tsv)
echo -e "${GREEN}✓ Azure CLI installed: $AZ_VERSION${NC}"

# Login to Azure
echo ""
echo -e "${YELLOW}Logging in to Azure...${NC}"
ACCOUNT=$(az account show --output json 2>/dev/null || echo "")
if [ -n "$ACCOUNT" ]; then
    USER_NAME=$(echo $ACCOUNT | jq -r '.user.name')
    SUBSCRIPTION_NAME=$(echo $ACCOUNT | jq -r '.name')
    echo -e "${GREEN}✓ Already logged in as: $USER_NAME${NC}"
    echo -e "${GRAY}  Subscription: $SUBSCRIPTION_NAME${NC}"
else
    echo -e "${YELLOW}Not logged in. Opening browser for authentication...${NC}"
    az login
fi

# Create Resource Group
echo ""
echo -e "${YELLOW}Creating resource group: $RESOURCE_GROUP_NAME in $LOCATION...${NC}"
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION" --output none
echo -e "${GREEN}✓ Resource group created successfully${NC}"

# Deploy ARM Template
echo ""
echo -e "${YELLOW}Deploying Storage Account...${NC}"
echo -e "${GRAY}  Name: $STORAGE_ACCOUNT_NAME${NC}"
echo -e "${GRAY}  Location: $LOCATION${NC}"

az deployment group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file "arm-template-storage.json" \
    --parameters storageAccountName="$STORAGE_ACCOUNT_NAME" location="$LOCATION" \
    --output none

echo -e "${GREEN}✓ Storage Account deployed successfully${NC}"

# Enable Static Website Hosting
echo ""
echo -e "${YELLOW}Enabling static website hosting...${NC}"
az storage blob service-properties update \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --static-website \
    --index-document index.html \
    --404-document index.html \
    --auth-mode login

echo -e "${GREEN}✓ Static website hosting enabled${NC}"

# Set container permissions
echo ""
echo -e "${YELLOW}Setting container permissions...${NC}"
az storage container set-permission \
    --name '$web' \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --public-access blob \
    --auth-mode login

echo -e "${GREEN}✓ Container permissions set${NC}"

# Upload files
echo ""
echo -e "${YELLOW}Uploading application files...${NC}"

FILES_TO_UPLOAD=("index.html" "styles.css" "app.js" "staticwebapp.config.json")
UPLOAD_SUCCESS=true

for file in "${FILES_TO_UPLOAD[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GRAY}  Uploading $file...${NC}"
        az storage blob upload \
            --account-name "$STORAGE_ACCOUNT_NAME" \
            --container-name '$web' \
            --name "$file" \
            --file "$file" \
            --auth-mode login \
            --overwrite \
            --output none
        echo -e "${GREEN}    ✓ $file uploaded${NC}"
    else
        echo -e "${RED}    X File not found: $file${NC}"
        UPLOAD_SUCCESS=false
    fi
done

# Get the website URL
echo ""
WEBSITE_URL=$(az storage account show \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "primaryEndpoints.web" \
    -o tsv)

if [ "$UPLOAD_SUCCESS" = true ]; then
    echo -e "${GREEN}========================================"
    echo -e "✓ DEPLOYMENT SUCCESSFUL!"
    echo -e "========================================${NC}"
    echo ""
    echo -e "${NC}Your Data Obfuscator is now live at:${NC}"
    echo -e "${CYAN}  $WEBSITE_URL${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "${NC}  1. Visit the URL above to test your app${NC}"
    echo -e "${NC}  2. Bookmark it for easy access${NC}"
    echo -e "${NC}  3. Share with your team${NC}"
    echo ""
    echo -e "${GRAY}Storage account name: $STORAGE_ACCOUNT_NAME${NC}"
    echo ""
    echo -e "${YELLOW}To delete the deployment:${NC}"
    echo -e "${GRAY}  az group delete --name $RESOURCE_GROUP_NAME --yes${NC}"
    echo ""
    echo -e "${GRAY}Estimated cost: < £1/month for typical usage${NC}"
else
    echo -e "${RED}X Some files failed to upload!${NC}"
    echo ""
    echo -e "${YELLOW}Manual upload option:${NC}"
    echo -e "${NC}  1. Go to Azure Portal: https://portal.azure.com${NC}"
    echo -e "${NC}  2. Navigate to storage account: $STORAGE_ACCOUNT_NAME${NC}"
    echo -e "${NC}  3. Click 'Containers' -> '\$web'${NC}"
    echo -e "${NC}  4. Upload these files:${NC}"
    echo -e "${GRAY}     - index.html${NC}"
    echo -e "${GRAY}     - styles.css${NC}"
    echo -e "${GRAY}     - app.js${NC}"
    echo -e "${GRAY}     - staticwebapp.config.json${NC}"
    echo ""
    echo -e "${CYAN}Your website URL: $WEBSITE_URL${NC}"
    exit 1
fi
