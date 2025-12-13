# Donate Screen Blank Fix - TODO

## Problem Analysis
The donate screen appears completely blank in the APK. This is likely due to:
1. Errors in async data loading (church data, user info)
2. Missing error handling for failed Supabase queries
3. Empty userInfo map passed from facebook_home_screen.dart
4. Payment config placeholders causing issues

## Steps to Complete
- [ ] Add error handling and loading states to donate_screen.dart
- [ ] Fix userInfo passing from facebook_home_screen.dart
- [ ] Add try-catch blocks around all Supabase queries
- [ ] Add fallback UI when data loading fails
- [ ] Test church selection functionality
- [ ] Verify payment method selection works
- [ ] Add debug logging to identify where the blank screen occurs
- [ ] Test with proper user authentication
- [ ] Ensure all required dependencies are imported
- [ ] Add loading indicators for async operations

## Current Issues Found
- facebook_home_screen.dart passes empty userInfo: `DonateScreen(userInfo: const {})`
- No error boundaries in donate_screen.dart
- Church loading failures not handled gracefully
- Payment config has placeholder values that may cause runtime errors

## Expected Behavior
- Screen should show donation form with purpose selection, amount input, payment methods
- Church selection should work for "Church" donations
- Loading states should be shown during data fetching
- Error messages should appear if data loading fails
