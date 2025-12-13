# Sign Up Screen Dynamic Fields & Authentication Fix

## Issues Identified
1. Authentication failure: User data not properly inserted to 'users' table after Supabase auth
2. Sign up screen not dynamic: All fields shown regardless of church position

## Plan
- [ ] Modify position field to dropdown with predefined options
- [ ] Add logic to show/hide fields based on selected position
- [ ] Set user role based on position (pastor positions get 'pastor' role)
- [ ] Add better error handling for signup failures
- [ ] Ensure user data insert happens properly

## Files to Edit
- flutter_projects/my_flutter_app/lib/sign_in.dart

## Testing
- [ ] Test signup with different positions
- [ ] Verify role-based navigation (pastors to PastorDashboard)
- [ ] Test authentication on APK
