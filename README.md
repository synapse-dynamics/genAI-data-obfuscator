# genAI-data-obfuscator

## Overview

No one knows for sure what happens to the data you submit to public GenAI. But using it for data analysis can often save valuable time. 

This tool will help you keep identifiable data out of the reach of genAI by anonymising your data before pasting into a chat. It will find and replace all keywords or terms you define with something random instead. The sanitised output will allow GenAI to understand context - without having real, identifiable information.

This is executed client-sided, so no input or output data is stored on any servers. This project is lightweight, open source and can be deployed and hosted on your own Azure Blob Storage within 2-3 minutes.

Note: If you are processing any sensitive or business data, please refer to your organisation's internal guidelines on generative AI use and data processing.

Hosted example: https://dataobfuscator3675.z6.web.core.windows.net/

## Features
- ✅ **Low-cost deployment** using Azure Blob Storage 
- ✅ **100% client-side processing** - no backend, no data storage
- ✅ **GUI file upload** available in Azure Portal
- ✅ **Custom obfuscation rules** with case sensitivity and whole-word matching
- ✅ **Preset templates** for common scenarios (corporate, personal, financial)
- ✅ **Save/load rules** as JSON files
- ✅ **Browser local storage** for persistent rules
- ✅ **One-click copy** to clipboard
- ✅ **Responsive design** works on mobile and desktop

## Architecture
```
┌─────────────────────────────────────────┐
│  Azure Storage Account (Standard_LRS) 
│   ├─ Static Website Hosting Enabled  
│   └─ $web Container (Public Blob)      
│       ├─ index.html                     
│       ├─ styles.css                     
│       ├─ app.js                         
│       └─ staticwebapp.config.json      
└─────────────────────────────────────────┘
         ↓
    HTTPS Only
         ↓
┌─────────────────────────────────────────┐
│         User's Browser                  
│   All processing happens here           
│   No data leaves the browser            
└─────────────────────────────────────────┘
```

## Deployment Instructions

### Option 1: Deploy via PowerShell Script (Easiest)

```powershell
cd azure-data-obfuscator
.\deploy.ps1
```

The script will:
1. ✓ Login to Azure
2. ✓ Create resource group
3. ✓ Deploy Storage Account via ARM template
4. ✓ Enable static website hosting
5. ✓ Upload application files
6. ✓ Display your live URL


### Option 2: Manual Deployment

```powershell
# 1. Login to Azure
az login

# 2. Create resource group
az group create --name rg-data-obfuscator --location westeurope

# 3. Generate unique storage account name
$storageAccountName = "dataobfuscator" + (Get-Random -Maximum 9999)

# 4. Deploy ARM template
az deployment group create `
  --resource-group rg-data-obfuscator `
  --template-file arm-template-storage.json `
  --parameters storageAccountName=$storageAccountName

# 5. Enable static website hosting
az storage blob service-properties update `
  --account-name $storageAccountName `
  --static-website `
  --index-document index.html `
  --auth-mode login

# 6. Set container permissions
az storage container set-permission `
  --name '$web' `
  --account-name $storageAccountName `
  --public-access blob `
  --auth-mode login

# 7. Upload files
az storage blob upload --account-name $storageAccountName --container-name '$web' --name index.html --file index.html --auth-mode login --overwrite
az storage blob upload --account-name $storageAccountName --container-name '$web' --name styles.css --file styles.css --auth-mode login --overwrite
az storage blob upload --account-name $storageAccountName --container-name '$web' --name app.js --file app.js --auth-mode login --overwrite
az storage blob upload --account-name $storageAccountName --container-name '$web' --name staticwebapp.config.json --file staticwebapp.config.json --auth-mode login --overwrite

# 8. Get your URL
az storage account show --name $storageAccountName --query "primaryEndpoints.web" -o tsv
```

## Configuration

### ARM Template Parameters

```json
{
  "storageAccountName": "your-unique-name",  // 3-24 chars, lowercase+numbers
  "location": "westeurope"                   // or uksouth, ukwest, etc.
}
```

### Cost Estimation

**Blob Storage Static Website:**
- Storage: ~0.1 MB × £0.015/GB/month = ~£0.00
- Bandwidth: First 5 GB free, then £0.075/GB
  - 1,000 users × 100 KB = 0.1 GB = **£0.00**
  - 10,000 users × 100 KB = 1 GB = **£0.00**
- Operations: £0.0004 per 10,000 requests
  - 10,000 page loads = **£0.004**

**Perfect for:**
- Internal tools with <10,000 users/month
- Low to moderate usage
- Teams with limited budget
- Organizations wanting simple deployment

## Updating Your Application

### GUI Method (Easiest)
1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to your Storage Account
3. Click **"Containers"** in the left menu
4. Click on **"$web"** container
5. Click **"Upload"** button
6. Select updated files and upload (they'll overwrite existing files)

### Privacy Guarantees

- ✅ Your sensitive data never leaves your device
- ✅ No analytics or telemetry
- ✅ No third-party scripts
- ✅ Open source code (you can review it)
- ✅ Can be run completely offline (save as local files)

## Troubleshooting

### Common Issues

**Problem**: Can't access the website
- ✓ Wait 1-2 minutes after deployment for DNS propagation
- ✓ Clear browser cache
- ✓ Verify files are in the $web container

**Problem**: Files not uploading via CLI
- ✓ Use `--auth-mode login` flag
- ✓ Ensure you have Storage Blob Data Contributor role
- ✓ Try uploading via Azure Portal GUI instead

**Problem**: Getting 404 errors
- ✓ Verify static website hosting is enabled
- ✓ Check that index.html exists in $web container
- ✓ Verify container has public blob access

### Storage Account Name Requirements

- Must be globally unique
- 3-24 characters long
- Lowercase letters and numbers only
- No hyphens, underscores, or special characters


### Check Costs

Go to Azure Portal → Cost Management → Cost Analysis to see your actual spending.

## Maintenance

### Minimal Maintenance Required

✅ **No server to patch**: Static files only
✅ **No database**: No backups needed
✅ **No runtime**: No version updates
✅ **Auto-scaling**: Azure handles traffic
✅ **99.9% SLA**: Built-in high availability

## Quick Reference

### Essential Commands
```powershell
# Deploy
.\deploy.ps1

# Get URL
az storage account show --name YOUR_STORAGE_NAME --query "primaryEndpoints.web" -o tsv

# Upload single file
az storage blob upload --account-name YOUR_STORAGE_NAME --container-name '$web' --name FILE.html --file FILE.html --auth-mode login --overwrite

# Delete
az group delete --name rg-data-obfuscator --yes
```

### File Structure
```
azure-data-obfuscator/
├── arm-template-storage.json      # Azure Resource Manager template for Storage
├── index.html                     # Main application page
├── styles.css                     # Styling
├── app.js                         # Application logic
├── staticwebapp.config.json       # Configuration (not used but included)
├── deploy.ps1             # Windows deployment script
└── README.md              # This file
```
