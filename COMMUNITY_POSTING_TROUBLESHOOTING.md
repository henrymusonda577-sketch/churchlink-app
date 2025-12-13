# Community Posting Troubleshooting Guide

## Issue: "Error loading posts" when posting videos or prayers

This guide will help you diagnose and fix issues with community posting functionality.

## 🔍 Step 1: Enable Debug Logging

The app now has enhanced error logging. Run the app and check the console for detailed error messages when:

1. Trying to post content
2. Loading the community screen
3. Any other error messages

## 🧪 Step 2: Run Diagnostic Test

Run the diagnostic test to check Firebase connectivity:

```bash
cd flutter_projects/my_flutter_app
dart test_community_posting.dart
```

This will test:
- Firebase Authentication
- Firestore database access
- Firebase Storage access
- Collection permissions

## 🔧 Step 3: Common Issues and Solutions

### Issue 1: Firestore Security Rules
**Symptoms**: Permission denied errors when reading/writing to collections

**Solution**: Check your Firestore security rules. Ensure they allow read/write access to:
- `community_posts`
- `prayers` 
- `videos`
- `posts`

Example rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write for authenticated users
    match /community_posts/{document} {
      allow read, write: if request.auth != null;
    }
    match /prayers/{document} {
      allow read, write: if request.auth != null;
    }
    match /videos/{document} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Issue 2: Firebase Storage Rules
**Symptoms**: Video uploads fail with permission errors

**Solution**: Check Storage security rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /videos/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /community_images/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Issue 3: Network Connectivity
**Symptoms**: Timeout errors or no response

**Solution**:
- Check internet connection
- Verify Firebase project configuration
- Ensure correct Firebase project is linked

### Issue 4: Authentication Issues
**Symptoms**: "No authenticated user" errors

**Solution**:
- Ensure user is properly signed in
- Check Firebase Authentication configuration
- Verify email verification if required

## 📋 Step 4: Testing Workflow

1. **Run the diagnostic test** to identify connectivity issues
2. **Check console logs** for specific error messages
3. **Test posting functionality** with the improved error handling
4. **Verify Firestore rules** if permission errors occur
5. **Test with different content types** (text, prayer, video)

## 🎯 Step 5: Specific Scenarios

### Video Upload Issues
- Check if video file size is within Firebase Storage limits
- Verify video format compatibility
- Ensure Storage rules allow uploads

### Prayer Posting Issues
- Verify `prayers` collection exists in Firestore
- Check Firestore rules for the prayers collection

### General Posting Issues
- Ensure user is authenticated
- Check network connectivity
- Verify Firebase project configuration

## 📊 Step 6: Monitoring

After implementing fixes:
1. Monitor console logs for any remaining errors
2. Test all posting functionality
3. Verify posts appear in the community feed
4. Check that videos can be uploaded and played

## 🆘 Getting Help

If issues persist:
1. Share the console error messages
2. Provide your Firestore security rules
3. Share your Firebase project configuration
4. Describe the exact steps to reproduce the issue

## ✅ Success Indicators

When fixed, you should be able to:
- ✅ Post text content to community
- ✅ Post prayers successfully  
- ✅ Upload and post videos
- ✅ See posts in the community feed
- ✅ Like and comment on posts
- ✅ No "error loading posts" messages
