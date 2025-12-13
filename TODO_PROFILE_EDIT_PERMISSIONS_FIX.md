# TODO: Fix Profile Edit Permissions for APK

## Issue
Users cannot edit their profile pictures in the APK because runtime permissions for camera and storage are not being requested on Android API 23+.

## Root Cause
- AndroidManifest.xml has the permissions declared
- But the app doesn't request them at runtime when needed
- This causes image picker to fail silently or crash

## Plan
- [x] Add permission_handler import to edit_profile_screen.dart
- [x] Create permission request methods for camera and gallery
- [x] Modify _pickImage() and _takePhoto() to request permissions first
- [x] Add proper error handling for permission denied cases
- [ ] Test on APK to ensure profile editing works

## Files to Edit
- flutter_projects/my_flutter_app/lib/edit_profile_screen.dart

## Testing
- [ ] Test gallery image selection
- [ ] Test camera photo taking
- [ ] Test permission denied scenarios
- [ ] Verify APK build and functionality
