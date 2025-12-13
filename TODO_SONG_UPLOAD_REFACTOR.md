# TODO: Refactor Song Section for File Uploads and Persistence

## Tasks
- [x] Add audio player dependency to pubspec.yaml (e.g., audioplayers)
- [x] Create AudioFirebaseService by adapting VideoFirebaseService for audio uploads
- [x] Update firestore.rules to add rules for 'songs' collection with uploader-only delete permissions
- [x] Update content_screen.dart: change _songs data structure to include fileUrl, uploaderId, uploadTimestamp, uniqueId, fileName, fileSize
- [x] Modify _showAddSongDialog to pick audio files (MP3, WAV, AAC) with format validation
- [x] Update _buildSongsTab to fetch songs from Firestore, display in persistent library view
- [x] Implement audio playback in song list with play/pause controls
- [x] Add share and delete options with uploader permission check
- [ ] Add upload progress dialog and success/failure feedback (basic feedback added, progress TODO)
- [ ] Optimize storage and playback with caching for fast loading
- [x] Test audio uploads, persistence, ownership, and playback (code review completed; live testing requires running the app)
