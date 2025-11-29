# Azure Data Obfuscator - PowerShell Deployment Script (Blob Storage)
# This script deploys the Data Obfuscator to Azure Blob Storage Static Website

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-data-obfuscator",
    
    [Parameter(Mandatory=$false)]
    [string]$StorageAccountName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "westeurope"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Data Obfuscator Azure Deployment" -ForegroundColor Cyan
Write-Host "    (Blob Storage Static Website)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Generate unique storage account name if not provided
if ([string]::IsNullOrEmpty($StorageAccountName)) {
    $randomSuffix = Get-Random -Maximum 9999
    $StorageAccountName = "dataobfuscator$randomSuffix"
    Write-Host "Generated storage account name: $StorageAccountName" -ForegroundColor Cyan
}

# Validate storage account name
if ($StorageAccountName -notmatch '^[a-z0-9]{3,24}$') {
    Write-Host "X Storage account name must be 3-24 characters, lowercase letters and numbers only" -ForegroundColor Red
    exit 1
}

# Check if Azure CLI is installed
Write-Host "Checking prerequisites..." -ForegroundColor Yellow
$azCheck = Get-Command az -ErrorAction SilentlyContinue
if (-not $azCheck) {
    Write-Host "X Azure CLI is not installed!" -ForegroundColor Red
    Write-Host "  Please install from: https://aka.ms/installazurecliwindows" -ForegroundColor Yellow
    exit 1
}

$azVersionOutput = az version --output json 2>$null
if ($azVersionOutput) {
    $azVersion = $azVersionOutput | ConvertFrom-Json
    Write-Host "checkmark Azure CLI installed: $($azVersion.'azure-cli')" -ForegroundColor Green
}

# Login to Azure
Write-Host ""
Write-Host "Logging in to Azure..." -ForegroundColor Yellow
$accountOutput = az account show --output json 2>$null
if ($accountOutput) {
    $account = $accountOutput | ConvertFrom-Json
    Write-Host "checkmark Already logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "  Subscription: $($account.name)" -ForegroundColor Gray
} else {
    Write-Host "Not logged in. Opening browser for authentication..." -ForegroundColor Yellow
    az login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "X Login failed!" -ForegroundColor Red
        exit 1
    }
}

# Create Resource Group
Write-Host ""
Write-Host "Creating resource group: $ResourceGroupName in $Location..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "checkmark Resource group created successfully" -ForegroundColor Green
} else {
    Write-Host "X Failed to create resource group" -ForegroundColor Red
    exit 1
}

# Deploy ARM Template
Write-Host ""
Write-Host "Deploying Storage Account..." -ForegroundColor Yellow
Write-Host "  Name: $StorageAccountName" -ForegroundColor Gray
Write-Host "  Location: $Location" -ForegroundColor Gray

$deploymentOutput = az deployment group create --resource-group $ResourceGroupName --template-file "arm-template-storage.json" --parameters storageAccountName=$StorageAccountName location=$Location --output json

if ($LASTEXITCODE -eq 0) {
    Write-Host "checkmark Storage Account deployed successfully" -ForegroundColor Green
} else {
    Write-Host "X Deployment failed!" -ForegroundColor Red
    exit 1
}

# Enable Static Website Hosting
Write-Host ""
Write-Host "Enabling static website hosting..." -ForegroundColor Yellow
az storage blob service-properties update --account-name $StorageAccountName --static-website --index-document index.html --404-document index.html --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "checkmark Static website hosting enabled" -ForegroundColor Green
} else {
    Write-Host "X Failed to enable static website hosting" -ForegroundColor Red
    exit 1
}

# Set container permissions
Write-Host ""
Write-Host "Setting container permissions..." -ForegroundColor Yellow
az storage container set-permission --name '$web' --account-name $StorageAccountName --public-access blob

if ($LASTEXITCODE -eq 0) {
    Write-Host "checkmark Container permissions set" -ForegroundColor Green
} else {
    Write-Host "! Warning: Failed to set container permissions (may need to do manually)" -ForegroundColor Yellow
}

# Upload files
Write-Host ""
Write-Host "Uploading application files..." -ForegroundColor Yellow

$filesToUpload = @("index.html", "styles.css", "app.js", "staticwebapp.config.json")
$uploadSuccess = $true

foreach ($file in $filesToUpload) {
    if (Test-Path $file) {
        Write-Host "  Uploading $file..." -ForegroundColor Gray
        az storage blob upload --account-name $StorageAccountName --container-name '$web' --name $file --file $file --overwrite --output none
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    checkmark $file uploaded" -ForegroundColor Green
        } else {
            Write-Host "    X Failed to upload $file" -ForegroundColor Red
            $uploadSuccess = $false
        }
    } else {
        Write-Host "    X File not found: $file" -ForegroundColor Red
        $uploadSuccess = $false
    }
}

# Get the website URL
Write-Host ""
$websiteUrl = az storage account show --name $StorageAccountName --resource-group $ResourceGroupName --query "primaryEndpoints.web" -o tsv

if ($uploadSuccess) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "checkmark DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your Data Obfuscator is now live at:" -ForegroundColor White
    Write-Host "  $websiteUrl" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Visit the URL above to test your app" -ForegroundColor White
    Write-Host "  2. Bookmark it for easy access" -ForegroundColor White
    Write-Host "  3. Share with your team" -ForegroundColor White
    Write-Host ""
    Write-Host "Storage account name: $StorageAccountName" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To delete the deployment:" -ForegroundColor Yellow
    Write-Host "  az group delete --name $ResourceGroupName --yes" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Estimated cost: < £1/month for typical usage" -ForegroundColor Gray
} else {
    Write-Host "X Some files failed to upload!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual upload option:" -ForegroundColor Yellow
    Write-Host "  1. Go to Azure Portal: https://portal.azure.com" -ForegroundColor White
    Write-Host "  2. Navigate to storage account: $StorageAccountName" -ForegroundColor White
    Write-Host "  3. Click 'Containers' -> '$web'" -ForegroundColor White
    Write-Host "  4. Upload these files:" -ForegroundColor White
    Write-Host "     - index.html" -ForegroundColor Gray
    Write-Host "     - styles.css" -ForegroundColor Gray
    Write-Host "     - app.js" -ForegroundColor Gray
    Write-Host "     - staticwebapp.config.json" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Your website URL: $websiteUrl" -ForegroundColor Cyan
    exit 1
}
