# TODO: Fix Loading Errors in Facebook and Notifications Screens

## Current Issues
- FacebookHomeScreen shows "Error loading posts"
- NotificationsScreen shows "Error loading notifications"

## Root Causes
- PostService.getFollowedUsersPosts() has Firestore whereIn limitation (max 10 items)
- Insufficient error logging to diagnose issues
- Potential authentication or permission problems

## Tasks
- [x] Add detailed error logging in FacebookHomeScreen _buildPostsFeed method
- [x] Add detailed error logging in NotificationsScreen build method
- [x] Improve PostService.getFollowedUsersPosts() to handle >10 followed users
- [x] Test the fixes by running the app and checking for errors

## Summary of Changes
- Added detailed error logging in FacebookHomeScreen to capture snapshot errors, error details, and stack traces
- Added detailed error logging in NotificationsScreen to capture snapshot errors, error details, and stack traces
- Improved PostService.getFollowedUsersPosts() to handle more than 10 followed users by:
  - Splitting users into batches of 10
  - Using RxDart's CombineLatestStream to combine multiple query streams
  - Sorting combined results by timestamp
  - Created _MockQuerySnapshot class to handle combined results
- All changes maintain backward compatibility and improve error diagnostics

## Files to Edit
- flutter_projects/my_flutter_app/lib/facebook_home_screen.dart
- flutter_projects/my_flutter_app/lib/notifications_screen.dart
- flutter_projects/my_flutter_app/lib/services/post_service.dart
