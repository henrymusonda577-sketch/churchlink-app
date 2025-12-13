# Manual Video Testing Guide

## Quick Test Checklist

### Backend Tests
- [ ] Health check: `curl http://localhost:3001/health`
- [ ] Invalid format rejection
- [ ] No file upload rejection
- [ ] Valid video upload (if test.mp4 exists)

### Flutter App Tests
- [ ] App launches without errors
- [ ] Video player handles invalid URLs gracefully
- [ ] Retry button appears on errors
- [ ] Timeout handling works (30s)
- [ ] Video proxy service connects

### Platform-Specific Tests

#### Android
- [ ] Storage permissions granted
- [ ] Video selection from gallery works
- [ ] Playback works on different screen sizes
- [ ] Orientation changes handled
- [ ] Background playback works

#### iOS
- [ ] Photo library permissions granted
- [ ] Video selection from Photos works
- [ ] Playback works on iPhone/iPad
- [ ] Memory management good
- [ ] Orientation changes handled

#### Web
- [ ] Works in Chrome, Firefox, Safari, Edge
- [ ] Drag-and-drop upload works
- [ ] File picker works
- [ ] Network timeouts handled

#### Desktop
- [ ] File selection works
- [ ] Window resizing works
- [ ] Fullscreen mode works
- [ ] Multiple windows work

## Error Scenarios to Test

### Network Issues
- [ ] Disconnect during upload
- [ ] Slow network timeout
- [ ] Invalid signed URL
- [ ] Expired signed URL

### File Issues
- [ ] Unsupported format upload
- [ ] File too large (>5GB)
- [ ] Corrupted video file
- [ ] Empty file upload

### Authentication Issues
- [ ] Invalid Firebase credentials
- [ ] Missing service account
- [ ] Permission denied

## Performance Tests

### Upload Performance
- [ ] Small file (<100MB) upload time
- [ ] Large file (>1GB) upload time
- [ ] Multiple concurrent uploads

### Playback Performance
- [ ] Video load time
- [ ] Buffering performance
- [ ] Memory usage
- [ ] CPU usage

## Test Results Summary

| Test Category | Tests Run | Passed | Failed | Notes |
|---------------|-----------|--------|--------|-------|
| Backend API   |           |        |        |       |
| Flutter UI    |           |        |        |       |
| Android       |           |        |        |       |
| iOS           |           |        |        |       |
| Web           |           |        |        |       |
| Desktop       |           |        |        |       |
| Error Handling|           |        |        |       |
| Performance   |           |        |        |       |

## Critical Issues Found
1.
2.
3.

## Recommendations
1.
2.
3.

## Next Steps
1. Fix critical issues
2. Re-test failed scenarios
3. Performance optimization
4. User acceptance testing
