# TODO: Migrate Chat System from Firebase to Supabase

## Steps to Complete:
- [ ] Create Supabase migration files for chat tables (chats, messages, groups, typing indicators)
- [ ] Create new SupabaseChatService replacing FirebaseChatService
- [ ] Update ChatScreen to use SupabaseChatService
- [ ] Update ChatPage to use SupabaseChatService
- [ ] Update ChurchGroupChatPage to use SupabaseChatService
- [ ] Migrate media upload/download to Supabase Storage
- [ ] Update imports in all chat-related files to remove Firebase dependencies
- [ ] Test individual chat functionality with Supabase
- [ ] Test group chat functionality with Supabase
- [ ] Test media sharing (images, videos, voice) with Supabase Storage
- [ ] Update pubspec.yaml to remove Firebase chat dependencies if no longer needed
- [ ] Handle data migration from Firebase to Supabase if needed
