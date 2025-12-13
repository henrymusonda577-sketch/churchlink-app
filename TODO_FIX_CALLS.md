# Fix Video and Audio Calls in Messaging Screen

## Current Issues
- Video call and audio call buttons in chat dialog show "coming soon"
- Video calls tab shows placeholder text
- WebRTC implementation is stubbed out
- flutter_webrtc package not included in pubspec.yaml

## Tasks
- [ ] Add flutter_webrtc dependency to pubspec.yaml
- [ ] Implement WebRTC functionality in webrtc_call_service.dart
- [ ] Uncomment and fix flutter_webrtc import in call_manager.dart
- [ ] Update chat_screen.dart to start actual calls instead of showing dialogs
- [ ] Implement _buildVideoCallsTab to show real video calls
- [ ] Test audio and video calls
- [ ] Handle permissions and errors

## Files to Edit
- pubspec.yaml
- lib/services/webrtc_call_service.dart
- lib/services/call_manager.dart
- lib/chat_screen.dart

## Followup
- Run flutter pub get
- Test calls between users
- Fix any WebRTC connection issues
