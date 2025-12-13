# Fix Voice Recording Overflow in Messaging Screen

## Issue
Voice recordings sent in the messaging screen (chat_screen.dart dialog) are causing "overflowed by pixels" error because the message display doesn't handle different message types properly and lacks width constraints.

## Plan
- [x] Update _showChatDialog in chat_screen.dart to use _buildMessageBubble for displaying messages instead of simple Text
- [x] Add maxWidth constraints to message bubble Containers to prevent overflow
- [x] Test voice message display in messaging screen

## Implementation Details
1. Replace the itemBuilder in _showChatDialog ListView with _buildMessageBubble(msg, fromMe)
2. Add constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75) to each _build*MessageBubble Container
3. Ensure voice messages display with proper play button and duration without overflowing

## Testing
- Send voice message in individual chat
- Verify no overflow error
- Check play/pause functionality
