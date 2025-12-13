# Quick error check script
Write-Host "Checking for compilation errors..." -ForegroundColor Yellow

# Navigate to project directory
Set-Location "C:\Users\smuso\OneDrive\Templtes\flutter_projects\my_flutter_app"

# Try to analyze the code
try {
    Write-Host "Running flutter analyze..." -ForegroundColor Green
    flutter analyze --no-fatal-infos --no-fatal-warnings
    
    Write-Host "Analysis complete!" -ForegroundColor Green
} catch {
    Write-Host "Flutter analyze failed: $_" -ForegroundColor Red
    Write-Host "Trying pub get first..." -ForegroundColor Yellow
    
    try {
        flutter pub get
        flutter analyze --no-fatal-infos --no-fatal-warnings
    } catch {
        Write-Host "Still failing. Check Flutter installation." -ForegroundColor Red
    }
}

Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")