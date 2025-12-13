# Voice Recording Display Fix

## Issue
Voice recordings are not showing in the church group chat screen and the pastor's dashboard chat screen, but they work in the messaging screen.

## Plan Steps
- [ ] Fix chat_screen.dart to handle different message types (voice, image, video)
- [ ] Add chat functionality to pastor_dashboard.dart
- [ ] Verify church_group_chat_page.dart voice message handling
- [ ] Test voice message recording and playback across all screens
- [ ] Ensure proper message type handling for all media types

## Implementation Details
1. **chat_screen.dart**: Add message type handling similar to church_group_chat_page.dart
2. **pastor_dashboard.dart**: Add chat tab to view church group messages
3. **church_group_chat_page.dart**: Verify and fix if needed

## Testing Checklist
- [ ] Voice message recording in individual chats
- [ ] Voice message display in individual chats
- [ ] Voice message recording in church group chats
- [ ] Voice message display in church group chats
- [ ] Voice message display in pastor dashboard
- [ ] Image and video message handling
