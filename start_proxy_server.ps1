# Start Video Upload Proxy Server
# This script starts the Node.js proxy server for video uploads

Write-Host "Starting Video Upload Proxy Server..." -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Yellow

# Check if Node.js is installed
try {
    $nodeVersion = node --version
    Write-Host "Node.js version: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "Error: Node.js is not installed. Please install Node.js first." -ForegroundColor Red
    Write-Host "Download from: https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

# Check if npm is available
try {
    $npmVersion = npm --version
    Write-Host "npm version: $npmVersion" -ForegroundColor Green
} catch {
    Write-Host "Error: npm is not available." -ForegroundColor Red
    exit 1
}

# Navigate to backend_proxy directory
$proxyDir = Join-Path $PSScriptRoot "backend_proxy"
if (!(Test-Path $proxyDir)) {
    Write-Host "Error: backend_proxy directory not found at $proxyDir" -ForegroundColor Red
    exit 1
}

Set-Location $proxyDir
Write-Host "Working directory: $proxyDir" -ForegroundColor Cyan

# Check if service-account.json exists
$serviceAccountPath = Join-Path $proxyDir "service-account.json"
if (!(Test-Path $serviceAccountPath)) {
    Write-Host "Warning: service-account.json not found!" -ForegroundColor Yellow
    Write-Host "Please download your Firebase service account key from Firebase Console" -ForegroundColor Yellow
    Write-Host "and save it as 'service-account.json' in the backend_proxy directory." -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    Write-Host "Steps:" -ForegroundColor Yellow
    Write-Host "1. Go to https://console.firebase.google.com/" -ForegroundColor Yellow
    Write-Host "2. Select your project (allchurches-956e0)" -ForegroundColor Yellow
    Write-Host "3. Go to Project Settings > Service Accounts" -ForegroundColor Yellow
    Write-Host "4. Click 'Generate new private key'" -ForegroundColor Yellow
    Write-Host "5. Save the JSON file as 'service-account.json' in backend_proxy/" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    $continue = Read-Host "Do you want to continue anyway? (y/n)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        exit 1
    }
}

# Install dependencies if node_modules doesn't exist
if (!(Test-Path (Join-Path $proxyDir "node_modules"))) {
    Write-Host "Installing dependencies..." -ForegroundColor Cyan
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to install dependencies" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Starting proxy server..." -ForegroundColor Green
Write-Host "Server will be available at: http://localhost:3001" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host "" -ForegroundColor Yellow

# Start the server
npm start
