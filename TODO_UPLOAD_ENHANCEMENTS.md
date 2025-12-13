# TODO: Upload Enhancements Implementation

## Steps to Complete

### 1. Enhance Post Creation
- [ ] Add image compression/resize in `create_post_screen.dart`
- [ ] Implement retry logic for failed uploads
- [ ] Add format validation for posts

### 2. Implement Chunked Video Uploads
- [ ] Modify `video_firebase_service.dart` for chunked uploads
- [ ] Add background processing support
- [ ] Optimize for mobile formats

### 3. Fix Song Deletion Permissions
- [ ] Update `content_screen.dart` to only allow uploader to delete songs
- [ ] Add user ID tracking for songs in data structure

### 4. Profile Picture Validation
- [ ] Add appropriate prompts/validation in `edit_profile_screen.dart`
- [ ] Ensure prompts only show when needed (not always)

### 5. Consistent Error Handling
- [ ] Standardize error messages and user feedback across all upload processes
- [ ] Add progress indicators for uploads

### 6. Testing and Verification
- [ ] Test all upload functionalities
- [ ] Verify song deletion permissions
- [ ] Confirm profile picture prompts work correctly
- [ ] Run integration tests
