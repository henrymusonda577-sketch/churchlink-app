# Firestore Index Setup Guide

## Issue Identified
Your Firestore queries require composite indexes that haven't been created yet. This is causing the "error loading posts" issue.

## Required Indexes

### Index 1: Community Posts by postType and createdAt
**Collection**: `community_posts`
**Fields**: 
- `postType` (Ascending)
- `createdAt` (Descending)

**Create Link**: 
https://console.firebase.google.com/v1/r/project/allchurches-956e0/firestore/indexes?create_composite=Cllwcm9qZWN0cy9hbGxjaHVyY2hlcy05NTZlMC9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvY29tbXVuaXR5X3Bvc3RzL2luZGV4ZXMvXxABGgwKCHBvc3RUeXBlEAEaDQoJY3JlYXRlZEF0EAIaDAoIX19uYW1lX18QAg

### Index 2: (Likely for comments/likes queries)
**Collection**: (Appears to be related to comments or likes)
**Fields**: 
- `likes` (Ascending)
- `comments` (Ascending)

**Create Link**: 
https://console.firebase.google.com/v1/r/project/allchurches-956e0/firestore/indexes?create_composite=Cllwcm9qZWN0cy9hbGxjaHVyY2hlcy05NTZlMC9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvY29tbXVuaXR5X3Bvc3RzL2luZGV4ZXMvXxABGgkKBWxpa2VzEAIaDAoIY29tbWVudHMQAhoMCghfX25hbWVfXxAC

## Steps to Fix

1. **Click the first link** above to create the community_posts index
2. **Click the second link** to create the comments/likes index
3. **Wait for indexes to build** (this can take a few minutes)
4. **Restart your app** and test posting functionality

## Alternative Manual Setup

If the links don't work, you can manually create the indexes:

### Index 1: Community Posts
- Go to Firebase Console → Firestore → Indexes
- Click "Create Index"
- Collection ID: `community_posts`
- Fields:
  - Field 1: `postType` (Ascending)
  - Field 2: `createdAt` (Descending)
- Query scope: Collection

### Index 2: Comments/Likes
- Collection ID: (check which collection needs this)
- Fields:
  - Field 1: `likes` (Ascending)  
  - Field 2: `comments` (Ascending)
- Query scope: Collection

## Testing After Index Creation

After creating the indexes:
1. Wait a few minutes for them to build
2. Restart your Flutter app
3. Try posting content again
4. The "error loading posts" should be resolved

## Additional Notes

- Index creation is free but may take a few minutes to propagate
- You only need to create these indexes once per project
- Future similar queries will use the same indexes
- The enhanced error handling will now show more specific errors if other issues arise

## Verification

To verify the indexes are working:
1. Check Firebase Console → Firestore → Indexes
2. Look for the new composite indexes
3. They should show status as "Enabled"
4. Test your app functionality
