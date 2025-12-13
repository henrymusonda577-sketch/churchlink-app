# Manual Firestore Index Setup Guide

## Issue: 403 Access Error
The automatic Firebase links require specific authentication. Here's how to manually create the required indexes:

## Step-by-Step Instructions

### 1. Access Firebase Console
1. Open your web browser and go to: https://console.firebase.google.com/
2. Sign in with the Google account that owns the "allchurches-956e0" project
3. Select your project from the list

### 2. Navigate to Firestore Indexes
1. In the left sidebar, click on "Firestore Database"
2. Click on the "Indexes" tab at the top

### 3. Create First Index (Community Posts)
1. Click the "Create Index" button
2. Fill in the following details:
   - **Collection ID**: `community_posts`
   - **Field 1**: `postType` (Ascending)
   - **Field 2**: `createdAt` (Descending)
   - **Query scope**: Collection
3. Click "Create"

### 4. Create Second Index (Comments/Likes)
1. Click "Create Index" again
2. Fill in the following details:
   - **Collection ID**: `community_posts` (or check which collection needs this)
   - **Field 1**: `likes` (Ascending)
   - **Field 2**: `comments` (Ascending)
   - **Query scope**: Collection
3. Click "Create"

### 5. Wait for Index Building
- The indexes will show status as "Building" initially
- Wait 2-5 minutes for status to change to "Enabled"
- You can continue working while indexes build

### 6. Test Your Application
1. Restart your Flutter app
2. Try posting content (videos, prayers, etc.)
3. The "error loading posts" should be resolved

## Verification
- Return to Firebase Console → Firestore → Indexes
- Verify both indexes show status as "Enabled"
- Test all community posting functionality

## Troubleshooting
If you still encounter issues:
1. **403 Errors**: Ensure you're using the correct Google account with project owner permissions
2. **Index not building**: Wait longer (can take up to 10 minutes)
3. **Different error**: Check console for new error messages with the enhanced logging

## Enhanced Error Handling
The app now has improved error logging that will provide:
- Detailed error messages in console
- Stack traces for better debugging
- Specific information about what's failing

## Support
If you continue to experience issues:
1. Check the console for specific error messages
2. Verify Firebase project configuration
3. Ensure all required Firebase services are enabled
