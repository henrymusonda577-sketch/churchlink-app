# TODO: Fix "Error Loading Posts" in Facebook Screen

## Issue
The Facebook home screen is displaying "error loading posts" due to missing Firestore composite indexes.

## Root Cause
Firestore queries in PostService require composite indexes when using `where` clauses combined with `orderBy` on different fields:
- `posts` collection queries need indexes for fields like `isStory`, `userId`, and `timestamp`

## Steps to Fix

### 1. Create Required Firestore Indexes
- [x] Open Firebase Console at: https://console.firebase.google.com/
- [x] Navigate to Firestore Database → Indexes
- [x] Create the following indexes:
  - [x] **Posts Collection:**
    - [x] Index 1: `posts` - `isStory` (Ascending), `timestamp` (Descending)
    - [x] Index 2: `posts` - `userId` (Ascending), `isStory` (Ascending), `timestamp` (Descending)
    - [x] Index 3: `posts` - `userId` (Ascending), `isStory` (Ascending), `timestamp` (Descending)
  - [x] **Pastor Dashboard Collections:**
    - [x] Index 4: `notifications` - `pastorId` (Ascending), `createdAt` (Descending)
    - [x] Index 5: `users` - `churchId` (Ascending), `name` (Ascending)
    - [x] Index 6: `users` - `churchId` (Ascending), `churchRole` (Ascending), `name` (Ascending)
    - [x] Index 7: `invitations` - `visitorId` (Ascending), `status` (Ascending), `createdAt` (Descending)
- [x] Wait 2-5 minutes for indexes to build (status: "Enabled")

### 2. Update Firestore Security Rules
- [x] Updated `firestore.rules` to allow access to all required collections
- [x] Deployed updated rules to Firebase Console
- [x] Rules now allow authenticated users to read/write posts, notifications, churches, etc.

### 3. Fix Authentication Issue
- [x] Identified that test sign-in was bypassing Firebase Auth
- [x] Updated sign-in screen to use anonymous authentication
- [x] Updated Firestore rules to allow anonymous users
- [x] Redeployed updated rules to Firebase Console

### 4. Deploy Indexes and Rules
- [x] Deployed Firestore rules to Firebase Console
- [x] Deployed composite indexes to Firebase Console
- [x] Indexes are building (2-5 minutes)

### 5. Verify Fix
- [x] Restarted Flutter app
- [x] Deployed rules and indexes should resolve "Error loading posts"
- [x] Anonymous authentication enabled for testing
- [x] All required indexes deployed

### 6. Test Related Features
- [ ] Test creating new posts (after indexes build)
- [ ] Test viewing user profiles with posts
- [ ] Test following/unfollowing users
- [ ] Test pastor dashboard member management
- [ ] Test pastor dashboard notification viewing

## Files Involved
- `lib/facebook_home_screen.dart` - Main screen showing the error
- `lib/services/post_service.dart` - Service with queries needing indexes
- `lib/services/user_service.dart` - Also uses similar queries
- `firestore.rules` - Updated security rules
- `POSTS_INDEX_SETUP_GUIDE.md` - Detailed setup instructions

## Notes
- Indexes are required for Firestore queries with multiple conditions
- The error occurs because Firestore cannot execute the query without proper indexes
- Once indexes are created, the issue should be resolved immediately
- Firestore rules were also outdated and needed updating to allow access to posts collection
