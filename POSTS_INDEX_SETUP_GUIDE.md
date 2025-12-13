# Firestore Index Setup Guide for Posts Collection

## Issue: "Error loading posts" in Facebook Home Screen
The Facebook home screen is showing "error loading posts" because Firestore requires composite indexes for queries that combine `where` clauses with `orderBy` on different fields.

## Required Indexes for `posts` Collection

You need to create the following composite indexes in Firebase Console:

### 1. Index for Home Feed Posts
- **Collection ID**: `posts`
- **Fields**:
  1. `isStory` (Ascending)
  2. `timestamp` (Descending)

### 2. Index for User Posts
- **Collection ID**: `posts`
- **Fields**:
  1. `userId` (Ascending)
  2. `isStory` (Ascending)
  3. `timestamp` (Descending)

### 3. Index for Followed Users Posts
- **Collection ID**: `posts`
- **Fields**:
  1. `userId` (Ascending)
  2. `isStory` (Ascending)
  3. `timestamp` (Descending)

## Additional Indexes for Pastor Dashboard

### 4. Index for Pastor Notifications
- **Collection ID**: `notifications`
- **Fields**:
  1. `pastorId` (Ascending)
  2. `createdAt` (Descending)

### 5. Index for Church Members
- **Collection ID**: `users`
- **Fields**:
  1. `churchId` (Ascending)
  2. `name` (Ascending)

### 6. Index for Church Visitors
- **Collection ID**: `users`
- **Fields**:
  1. `churchId` (Ascending)
  2. `churchRole` (Ascending)
  3. `name` (Ascending)

### 7. Index for User Invitations
- **Collection ID**: `invitations`
- **Fields**:
  1. `visitorId` (Ascending)
  2. `status` (Ascending)
  3. `createdAt` (Descending)

## Step-by-Step Instructions

### 1. Access Firebase Console
1. Open your web browser and go to: https://console.firebase.google.com/
2. Sign in with the Google account that owns the "allchurches-956e0" project
3. Select your project from the list

### 2. Navigate to Firestore Indexes
1. In the left sidebar, click on "Firestore Database"
2. Click on the "Indexes" tab at the top

### 3. Create First Index (Home Feed)
1. Click the "Create Index" button
2. Fill in the following details:
   - **Collection ID**: `posts`
   - **Fields**:
     - Field path: `isStory` (Mode: Ascending)
     - Field path: `timestamp` (Mode: Descending)
   - **Query scope**: Collection
3. Click "Create"

### 4. Create Second Index (User Posts)
1. Click "Create Index" again
2. Fill in the following details:
   - **Collection ID**: `posts`
   - **Fields**:
     - Field path: `userId` (Mode: Ascending)
     - Field path: `isStory` (Mode: Ascending)
     - Field path: `timestamp` (Mode: Descending)
   - **Query scope**: Collection
3. Click "Create"

### 5. Create Third Index (Followed Users)
1. Click "Create Index" again
2. Fill in the following details:
   - **Collection ID**: `posts`
   - **Fields**:
     - Field path: `userId` (Mode: Ascending)
     - Field path: `isStory` (Mode: Ascending)
     - Field path: `timestamp` (Mode: Descending)
   - **Query scope**: Collection
3. Click "Create"

### 6. Wait for Index Building
- The indexes will show status as "Building" initially
- Wait 2-5 minutes for status to change to "Enabled"
- You can continue working while indexes build

### 7. Test Your Application
1. Restart your Flutter app
2. Navigate to the Facebook home screen
3. The "error loading posts" should be resolved

## Verification
- Return to Firebase Console → Firestore → Indexes
- Verify all three indexes show status as "Enabled"
- Test the Facebook home screen functionality

## Troubleshooting
If you still encounter issues:
1. **403 Errors**: Ensure you're using the correct Google account with project owner permissions
2. **Index not building**: Wait longer (can take up to 10 minutes)
3. **Different error**: Check console for new error messages

## Support
If you continue to experience issues:
1. Check the console for specific error messages
2. Verify Firebase project configuration
3. Ensure all required Firebase services are enabled
