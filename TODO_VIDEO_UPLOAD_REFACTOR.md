# Video Upload Refactor Plan

## Overview
Refactor video upload logic in content_screen.dart to match TikTok's reliability and performance, including chunked uploads, progress indicators, retry logic, format conversion, compression, and duplicate prevention.

## Steps to Complete

### 1. Update VideoFirebaseService
- [x] Add resumable upload support using Firebase Storage uploadTask with listeners
- [x] Implement progress callbacks for upload progress indicators
- [x] Add retry logic for failed uploads (up to 3 retries with exponential backoff)
- [x] Generate unique video IDs using timestamps and user IDs to prevent duplicates
- [x] Ensure unique storage paths to avoid overwrites

### 2. Add Video Processing Service
- [ ] Create new VideoProcessingService for compression and format conversion
- [x] Add video validation (size limit: 100MB, duration limit: 25 minutes)
- [ ] Implement automatic format conversion to MP4 for unsupported formats
- [ ] Add video compression and resolution optimization
- [ ] Support mobile-friendly formats (MP4, MOV)

### 3. Refactor ContentScreen Upload Logic
- [x] Update _pickAndAddVideo method to use new upload service
- [x] Add upload progress indicator UI (progress bar, percentage)
- [ ] Implement background processing for uploads
- [x] Improve error feedback with specific messages and retry options
- [x] Add validation before upload (size, duration checks)
- [x] Handle slow/unstable connections with chunked uploads

### 4. Security and Persistence
- [ ] Ensure uploaded videos are stored securely with proper Firebase Storage rules
- [ ] Verify videos persist unless deleted by uploader
- [ ] Add user authentication checks for uploads

### 5. Testing and Verification
- [ ] Test upload on slow/unstable connections
- [ ] Verify progress indicators and error feedback
- [ ] Test format conversion and compression
- [ ] Confirm duplicate prevention works
- [ ] Test retry logic on failures

## Dependencies
- Add video processing package (e.g., flutter_ffmpeg_kit) to pubspec.yaml for compression/conversion
- Update Firebase Storage rules if needed for security

## Followup Steps
- Update pubspec.yaml with required dependencies
- Test the refactored upload functionality
- Monitor performance and reliability improvements
