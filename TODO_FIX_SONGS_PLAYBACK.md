# TODO: Fix Gospel Songs Playback Issue

## Problem
The gospel songs (YouTube videos) were not playing in the app.

## Root Cause
- YouTube player was configured with `autoPlay: true`, which is restricted on many platforms due to YouTube policies.
- Controller lifecycle management was not optimal.
- No error handling for video playback failures.
- Widget not properly rebuilding when switching videos.

## Changes Made
- [x] Removed `autoPlay: true` from YoutubePlayerFlags and handle playback manually in `onReady` callback.
- [x] Added `_currentVideoId` variable to track the currently playing video.
- [x] Added error handling and listener to the YouTube controller to show error messages.
- [x] Added validation for video ID before creating controller.
- [x] Added `ValueKey(_currentVideoId)` to YoutubePlayer widget to force rebuild when video changes.
- [x] Updated conditions to show YoutubePlayer only when the video ID matches the current one.

## Testing
- [ ] Test playing gospel songs on different platforms (Android, iOS, Web).
- [ ] Verify error messages appear for invalid videos.
- [ ] Check that switching between songs works properly.
- [ ] Ensure audio player stops when YouTube video starts.

## Notes
- YouTube player does not require API key for basic playback.
- Thumbnails are served via the backend proxy to avoid CORS issues.
- Controller is properly disposed when switching songs or when widget is disposed.
