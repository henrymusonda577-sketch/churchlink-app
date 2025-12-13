# APK Fix Plan - Home Screen Only, Black Screens, Sign Up Issues

## Issues Identified
1. **Sign Up Not Working**: User data not properly inserted to 'users' table after Supabase auth
2. **Donate Screen Blank**: Empty userInfo map passed from facebook_home_screen.dart, async loading failures
3. **Black Screens**: Multiple screens showing black due to async data loading errors and missing error handling
4. **Home Screen Only**: Navigation issues preventing access to other screens

## Root Causes
- Empty userInfo maps passed between screens
- Missing error handling for Supabase queries
- Async data loading failures not handled gracefully
- User data insertion failures during signup
- RLS policies blocking data access

## Fix Plan

### Phase 1: Sign Up Fix
- [ ] Fix user data insertion in sign_in.dart
- [ ] Add retry logic for user data save
- [ ] Ensure proper error handling during signup
- [ ] Test signup with different positions

### Phase 2: User Info Propagation
- [ ] Fix facebook_home_screen.dart to pass proper userInfo
- [ ] Update main.dart to properly fetch and pass user info
- [ ] Ensure userInfo is available throughout the app

### Phase 3: Screen Loading Fixes
- [ ] Add loading states and error handling to donate_screen.dart
- [ ] Fix async data loading in all screens
- [ ] Add fallback UI when data loading fails
- [ ] Implement proper error boundaries

### Phase 4: Navigation Fixes
- [ ] Ensure all screens can be accessed from home
- [ ] Fix black screen issues in Bible and other screens
- [ ] Test navigation between all screens

### Phase 5: Testing
- [ ] Test APK build and installation
- [ ] Verify all screens load properly
- [ ] Test signup and login functionality
- [ ] Test donation and other features

## Files to Modify
- flutter_projects/my_flutter_app/lib/sign_in.dart
- flutter_projects/my_flutter_app/lib/facebook_home_screen.dart
- flutter_projects/my_flutter_app/lib/main.dart
- flutter_projects/my_flutter_app/lib/donate_screen.dart
- flutter_projects/my_flutter_app/lib/services/user_service.dart
- flutter_projects/my_flutter_app/lib/bible_screen.dart (if exists)
- Other screen files with loading issues

## Expected Outcome
- Sign up works properly with user data saved
- All screens load without black screens
- Proper navigation between screens
- Donate screen shows content
- APK functions correctly on device
