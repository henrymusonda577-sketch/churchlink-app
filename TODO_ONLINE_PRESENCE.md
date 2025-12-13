# TODO: Implement Online/Offline Presence System

## Completed Tasks
- [x] Create TODO.md file for tracking progress

## Pending Tasks
- [x] Update UserService (`user_service.dart`):
  - [x] Add `setUserOnline()` method
  - [x] Add `setUserOffline()` method
  - [x] Add `getUserPresence()` method
  - [x] Add `lastActive` field to user documents

- [x] Create PresenceService (`presence_service.dart`):
  - [x] Implement presence management logic
  - [x] Handle app lifecycle events (online/offline)
  - [x] Provide real-time presence streams

- [x] Integrate PresenceService into main.dart (app lifecycle)

- [ ] Update UI Components:
  - [x] facebook_home_screen.dart (posts, stories, comments)
  - [x] chat_screen.dart (chat lists, messages)
  - [x] community_screen.dart (user lists)
  - [x] profile_screen.dart (user profiles)
  - [ ] discover_people_screen.dart (user discovery)
  - [ ] notifications_screen.dart (notification senders)
  - [ ] Other screens: chat_page.dart, new_chat_page.dart, church_group_chat_page.dart, etc.

## Testing
- [ ] Test presence updates across screens
- [ ] Test offline/online transitions
- [ ] Test real-time updates

## Followup
- [ ] Update Firestore security rules if needed
- [ ] Handle edge cases (network issues, app crashes)
- [ ] Optimize performance (limit listeners, caching)
