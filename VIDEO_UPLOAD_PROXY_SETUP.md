# Video Upload Fix - Proxy Server Approach

This document explains how to fix video upload CORS issues by using a backend proxy server instead of configuring CORS in Firebase Storage.

## Problem
The original issue was CORS (Cross-Origin Resource Sharing) errors when uploading videos directly from the Flutter web app to Firebase Storage:

```
Access to XMLHttpRequest at 'https://firebasestorage.googleapis.com/v0/b/allchurches-956e0.appspot.com/o?name=content_videos%2F...' from origin 'http://localhost:8080' has been blocked by CORS policy
```

## Solution
Instead of dealing with CORS configuration, we'll use a Node.js proxy server that runs on your local machine and handles the video uploads to Firebase Storage. This approach:

- ✅ Bypasses CORS issues completely
- ✅ Uses Firebase Admin SDK (server-side authentication)
- ✅ Maintains the same Firebase Storage bucket
- ✅ Works for both development and production
- ✅ No need to configure CORS in Firebase Console

## Setup Instructions

### Step 1: Install Node.js
If you don't have Node.js installed:
1. Download from https://nodejs.org/
2. Install the LTS version
3. Verify installation: `node --version` and `npm --version`

### Step 2: Get Firebase Service Account Key
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project "allchurches-956e0"
3. Go to **Project Settings** → **Service Accounts** tab
4. Click **"Generate new private key"**
5. Save the downloaded JSON file as `service-account.json` in the `backend_proxy/` directory

### Step 3: Install Proxy Server Dependencies
```bash
cd flutter_projects/my_flutter_app/backend_proxy
npm install
```

### Step 4: Start the Proxy Server
Run the PowerShell script:
```powershell
.\start_proxy_server.ps1
```

Or manually:
```bash
cd backend_proxy
npm start
```

The server will start on `http://localhost:3001`

### Step 5: Test the Setup
1. Keep the proxy server running
2. Start your Flutter app: `flutter run --web-port 8080`
3. Try uploading a video - it should work without CORS errors

## How It Works

### Architecture
```
Flutter Web App (localhost:8080) → Proxy Server (localhost:3001) → Firebase Storage
```

### Code Changes Made

1. **Updated `content_screen.dart`**:
   - Added import for `VideoProxyService`
   - Created `VideoProxyService` instance pointing to `http://localhost:3001`
   - Replaced `_uploadVideoToStorage()` method to use proxy service

2. **Backend Proxy Server** (`backend_proxy/server.js`):
   - Express.js server with CORS enabled
   - Firebase Admin SDK for server-side authentication
   - Handles multipart file uploads
   - Automatically makes uploaded files public
   - Returns public URLs to the Flutter app

### API Flow
1. User selects video in Flutter app
2. Flutter app sends video to proxy server (`POST /upload-video`)
3. Proxy server uploads video to Firebase Storage using Admin SDK
4. Proxy server makes file public and gets download URL
5. Proxy server returns URL to Flutter app
6. Flutter app saves post with video URL to Firestore

## File Structure
```
flutter_projects/my_flutter_app/
├── backend_proxy/
│   ├── server.js          # Main proxy server
│   ├── package.json       # Dependencies
│   ├── README.md          # Setup instructions
│   ├── .gitignore         # Git ignore rules
│   └── service-account.json # Firebase credentials (download this)
├── lib/
│   ├── content_screen.dart     # Updated to use proxy
│   └── services/
│       └── video_proxy_service.dart # Proxy service client
└── start_proxy_server.ps1    # Startup script
```

## Troubleshooting

### "service-account.json not found"
- Make sure you downloaded the Firebase service account key
- Save it as `backend_proxy/service-account.json`
- Never commit this file to version control

### "Port 3001 already in use"
- Change the port in `backend_proxy/server.js`
- Or stop other services using port 3001

### "Upload failed" errors
- Check that Firebase Storage bucket exists
- Verify service account has proper permissions
- Check server logs for detailed error messages

### Proxy server won't start
- Ensure Node.js and npm are installed
- Run `npm install` in backend_proxy directory
- Check for any missing dependencies

## Production Deployment

For production deployment:

1. **Deploy proxy server** to a cloud service (Heroku, Railway, Vercel, etc.)
2. **Update proxy URL** in Flutter app from `localhost:3001` to your deployed URL
3. **Secure the proxy server** with authentication if needed
4. **Use environment variables** for sensitive configuration

## Security Considerations

- The `service-account.json` file contains sensitive credentials
- Never commit it to version control
- In production, use environment variables or secret management
- Consider adding authentication to the proxy endpoints
- The current setup makes all uploaded files public

## Alternative Approaches

If you prefer not to use a proxy server, you could also:

1. **Use Firebase Cloud Functions** - Serverless functions to handle uploads
2. **Configure CORS properly** in Firebase Storage (the original approach)
3. **Use a different storage service** like Cloudinary or AWS S3
4. **Upload via Firebase REST API** with proper authentication

## Support

If you encounter issues:
1. Check the server logs in the terminal running the proxy
2. Verify all files are in the correct locations
3. Ensure Firebase service account has proper permissions
4. Test the proxy server endpoints directly with tools like Postman

The proxy approach should resolve all CORS issues while maintaining the same functionality as direct Firebase Storage uploads.
