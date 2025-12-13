# Bible Verse Selection Integration in Create Post Screen

## Overview
Enhance the "Verse" option in the create post screen to allow users to select Bible verses directly from the Bible data instead of only manual typing.

## Steps to Complete

### Phase 1: Create Bible Verse Selector Screen
- [x] Create `lib/bible_verse_selector_screen.dart`
- [x] Implement tabbed interface for Old/New Testament
- [x] Add book selection list with proper ordering
- [x] Add chapter selection for selected book
- [x] Add verse selection with preview
- [x] Implement verse selection return with formatted text and reference
- [x] Add loading states and error handling
- [x] Support current translation preference

### Phase 2: Update Create Post Screen
- [x] Modify `_showVerseDialog()` in `create_post_screen.dart`
- [x] Add two options: "Type Verse" and "Select from Bible"
- [x] Implement navigation to verse selector screen
- [x] Handle returned selected verse and set in content controller
- [x] Update UI to reflect verse selection state
- [x] Test integration with existing post creation flow

### Phase 3: Testing and Polish
- [x] Test verse selection with different books/chapters/verses
- [x] Verify formatting of selected verses in posts
- [x] Test with different Bible translations
- [x] Ensure proper navigation and back button handling
- [x] Test on different screen sizes

## Files to Edit/Create
- `lib/bible_verse_selector_screen.dart` (NEW)
- `lib/create_post_screen.dart` (MODIFY)

## Technical Requirements
- Use existing BibleService for data access
- Follow app's design patterns and styling
- Maintain backward compatibility with manual verse entry
- Handle loading states gracefully
- Support user's preferred Bible translation

## Dependencies
- No new dependencies required
- Uses existing: BibleService, navigation patterns, theme provider
