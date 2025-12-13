# TODO: Verse of the Day Feature - User-Generated System

## Overview
Users can post their own verses. Popular verses (based on likes) become "Verse of the Day" and are prominently displayed at the top of the Facebook home screen for 3 days.

## Steps to Complete

### Phase 1: Core Verse Posting (COMPLETED)
- [x] Remove all predefined Bible verses from CreatePostScreen
- [x] Simplify verse dialog to direct text input (no random verses)
- [x] Add boolean state for verse selection
- [x] Modify media options row to include "Verse" button
- [x] Update UI to highlight selected verse option
- [x] Test basic verse posting functionality

### Phase 2: Verse of the Day System
- [ ] Create verse tracking service to monitor post likes
- [ ] Implement algorithm to select Verse of the Day based on likes
- [ ] Add Verse of the Day display widget for Facebook home screen
- [ ] Implement 3-day expiration system for Verse of the Day
- [ ] Add database fields to track Verse of the Day status and expiration
- [ ] Update Facebook home screen to show Verse of the Day at the top
- [ ] Add visual styling to make Verse of the Day prominent
- [ ] Test Verse of the Day selection and display logic

### Phase 3: User Experience Enhancements
- [ ] Add notification when user's verse becomes Verse of the Day
- [ ] Show Verse of the Day history/stats
- [ ] Add ability to share Verse of the Day
- [ ] Implement verse categorization/tagging system

## Files to Edit
- flutter_projects/my_flutter_app/lib/create_post_screen.dart (COMPLETED)
- flutter_projects/my_flutter_app/lib/facebook_home_screen.dart
- flutter_projects/my_flutter_app/lib/services/post_service.dart
- flutter_projects/my_flutter_app/lib/services/verse_service.dart (NEW)

## Technical Requirements
- Track verse posts separately from regular posts
- Implement like threshold for Verse of the Day selection
- Add expiration timestamp for 3-day display period
- Create prominent UI component for Verse of the Day
- Ensure Verse of the Day appears above regular posts feed

## Notes
- Only user-generated verses (no predefined Bible verses)
- Verse of the Day selected based on engagement (likes)
- 3-day display period for Verse of the Day
- Prominent placement at top of Facebook home screen
- Allow combining verses with images/videos
