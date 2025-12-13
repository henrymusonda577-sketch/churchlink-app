# Church Chat Voice Notes Enhancement

## Tasks
- [x] Update _buildMessageBubble to handle different message types (text, voice, image, video)
- [x] Add voice message UI with play button and duration display
- [x] Add image message display with proper sizing
- [x] Add video message display with thumbnail and play button
- [x] Test voice message recording, sending, and playback
- [x] Test image and video message sending and display
- [x] Ensure proper message bubble layout for all message types

## Implementation Details
1. Voice messages: Show microphone icon, duration, play/pause button
2. Image messages: Display image with max width constraint
3. Video messages: Show thumbnail with play overlay
4. Message types: Use messageData['messageType'] to determine display type
5. Media URL: Use messageData['mediaUrl'] for media content
6. Voice duration: Use messageData['voiceDuration'] for voice messages
