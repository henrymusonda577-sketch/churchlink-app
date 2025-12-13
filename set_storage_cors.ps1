# PowerShell script to set CORS for Firebase Storage
Write-Host "=== Firebase Storage CORS Configuration ===" -ForegroundColor Green
Write-Host "Project: allchurches-956e0" -ForegroundColor Yellow
Write-Host "Bucket: gs://allchurches-956e0.appspot.com" -ForegroundColor Yellow
Write-Host ""

# Check if Google Cloud SDK is installed
$gcloudInstalled = Get-Command gcloud -ErrorAction SilentlyContinue
if (-not $gcloudInstalled) {
    Write-Host "Google Cloud SDK is not installed. Please install it first:" -ForegroundColor Red
    Write-Host "Download from: https://cloud.google.com/sdk/docs/install" -ForegroundColor Cyan
    Write-Host "Then run: gcloud auth login" -ForegroundColor Cyan
    exit 1
}

Write-Host "Setting CORS configuration for Firebase Storage..." -ForegroundColor Green

# Set CORS for the bucket
try {
    gsutil cors set cors.json gs://allchurches-956e0.appspot.com
    Write-Host "`n✅ CORS configuration set successfully!" -ForegroundColor Green
    Write-Host "Please restart your Flutter app and test the profile picture upload." -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Error setting CORS configuration:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nManual steps:" -ForegroundColor Yellow
    Write-Host "1. Install Google Cloud SDK if not already installed" -ForegroundColor Cyan
    Write-Host "2. Run: gcloud auth login" -ForegroundColor Cyan
    Write-Host "3. Run: gsutil cors set cors.json gs://allchurches-956e0.appspot.com" -ForegroundColor Cyan
    Write-Host "4. Or set CORS via Firebase Console: https://console.firebase.google.com/project/allchurches-956e0/storage" -ForegroundColor Cyan
}

Write-Host "`nPress Enter to continue..." -ForegroundColor Gray
Read-Host
