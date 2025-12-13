# PowerShell script to help open Firebase Console
Write-Host "Opening Firebase Console for project: allchurches-956e0" -ForegroundColor Green

# Try to open the browser with the Firebase console
$firebaseURL = "https://console.firebase.google.com/project/allchurches-956e0/firestore/indexes"

try {
    # Try different methods to open the browser
    Write-Host "Attempting to open browser..." -ForegroundColor Yellow
    
    # Method 1: Using Start-Process (most reliable)
    Start-Process $firebaseURL
    
    Write-Host "✅ Browser should open with Firebase Console" -ForegroundColor Green
    Write-Host ""
    Write-Host "INSTRUCTIONS:" -ForegroundColor Cyan
    Write-Host "1. Make sure you're logged into the correct Google account" -ForegroundColor White
    Write-Host "2. Navigate to: Firestore Database → Indexes" -ForegroundColor White
    Write-Host "3. Click 'Create Index'" -ForegroundColor White
    Write-Host "4. Create these indexes:" -ForegroundColor White
    Write-Host "   - Collection: community_posts" -ForegroundColor White
    Write-Host "     Fields: postType (Ascending), createdAt (Descending)" -ForegroundColor White
    Write-Host "   - Collection: community_posts" -ForegroundColor White
    Write-Host "     Fields: likes (Ascending), comments (Ascending)" -ForegroundColor White
    Write-Host "5. Wait 2-5 minutes for indexes to build" -ForegroundColor White
    Write-Host "6. Restart your Flutter app" -ForegroundColor White
    
} catch {
    Write-Host "❌ Could not open browser automatically" -ForegroundColor Red
    Write-Host "Please manually open: $firebaseURL" -ForegroundColor Yellow
}

# Alternative manual instructions
Write-Host ""
Write-Host "ALTERNATIVE MANUAL STEPS:" -ForegroundColor Cyan
Write-Host "1. Open: https://console.firebase.google.com/" -ForegroundColor White
Write-Host "2. Select project: allchurches-956e0" -ForegroundColor White
Write-Host "3. Go to Firestore Database → Indexes" -ForegroundColor White
Write-Host "4. Create the required indexes" -ForegroundColor White

# Wait for user to read
Write-Host ""
Read-Host "Press Enter to continue after creating indexes..."
