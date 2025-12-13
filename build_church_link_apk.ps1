# Church-Link APK Builder for Tecno Pop 10 Compatibility
# Run this script in PowerShell as Administrator

Write-Host "Building Church-Link APK for Tecno Pop 10..." -ForegroundColor Green

# Set location to project directory
Set-Location "C:\Users\smuso\OneDrive\Templtes\flutter_projects\my_flutter_app"

# Clean previous builds
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
if (Test-Path "build") { Remove-Item -Recurse -Force "build" }
if (Test-Path ".dart_tool") { Remove-Item -Recurse -Force ".dart_tool" }

# Flutter commands
try {
    Write-Host "Getting Flutter dependencies..." -ForegroundColor Yellow
    flutter pub get
    
    Write-Host "Cleaning Flutter cache..." -ForegroundColor Yellow
    flutter clean
    
    Write-Host "Building universal APK (recommended for Tecno Pop 10)..." -ForegroundColor Yellow
    flutter build apk --release --no-shrink --no-tree-shake-icons
    
    Write-Host "Building fat APK as backup..." -ForegroundColor Yellow
    flutter build apk --release --target-platform android-arm,android-arm64 --no-shrink
    
    Write-Host "APK build completed successfully!" -ForegroundColor Green
    Write-Host "Universal APK location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Cyan
    
    # Check if APK was created
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        $apkSize = (Get-Item $apkPath).Length / 1MB
        Write-Host "APK Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Cyan
        Write-Host "APK is ready for installation on Tecno Pop 10!" -ForegroundColor Green
    } else {
        Write-Host "APK not found. Check for build errors above." -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error building APK: $_" -ForegroundColor Red
    Write-Host "Make sure Flutter SDK is installed and in PATH" -ForegroundColor Yellow
}

Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")