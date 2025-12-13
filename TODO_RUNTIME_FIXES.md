# Runtime Fixes TODO

## 1. Firestore Composite Indexes
- [ ] Create composite indexes for BibleService queries (bookmarks, notes, highlights, recent_verses)
- [ ] Create composite indexes for other services with multiple where clauses + orderBy
- [ ] Test Firestore queries after indexes are created

## 2. Camera/Microphone Permissions
- [ ] Verify AndroidManifest.xml has camera and microphone permissions
- [ ] Add permission request handling in WebRTCCallService
- [ ] Test permission requests on device

## 3. Image Loading Error Handling
- [ ] Add fallback UI for profile picture loading errors in FacebookHomeScreen
- [ ] Add fallback UI for post image loading errors in FacebookHomeScreen
- [ ] Add fallback UI for story image loading errors in FacebookHomeScreen
- [ ] Test image loading with invalid URLs

## 4. Documentation
- [ ] Create FIRESTORE_INDEXES.md with index creation instructions
- [ ] Create PERMISSIONS_SETUP.md with permission troubleshooting guide
- [ ] Update README.md with runtime error fixes
