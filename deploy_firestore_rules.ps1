# PowerShell script to deploy Firestore rules
Write-Host "=== Firestore Rules Deployment ===" -ForegroundColor Green
Write-Host "Project: allchurches-956e0" -ForegroundColor Yellow
Write-Host ""

# Check if Firebase CLI is installed
$firebaseInstalled = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebaseInstalled) {
    Write-Host "Firebase CLI is not installed. Please install it first:" -ForegroundColor Red
    Write-Host "npm install -g firebase-tools" -ForegroundColor Cyan
    Write-Host "Then run: firebase login" -ForegroundColor Cyan
    exit 1
}

Write-Host "Deploying Firestore rules..." -ForegroundColor Green

# Deploy Firestore rules
try {
    firebase deploy --only firestore:rules --project allchurches-956e0
    Write-Host "`n✅ Firestore rules deployed successfully!" -ForegroundColor Green
    Write-Host "Please restart your Flutter app and test posting functionality." -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Error deploying Firestore rules:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nManual deployment steps:" -ForegroundColor Yellow
    Write-Host "1. Go to: https://console.firebase.google.com/project/allchurches-956e0/firestore/rules" -ForegroundColor Cyan
    Write-Host "2. Copy the content from firestore.rules file" -ForegroundColor Cyan
    Write-Host "3. Paste into the rules editor" -ForegroundColor Cyan
    Write-Host "4. Click 'Publish'" -ForegroundColor Cyan
}

Write-Host "`nPress Enter to continue..." -ForegroundColor Gray
Read-Host
