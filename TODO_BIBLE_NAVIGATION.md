# TODO: Implement Bible Navigation

## Overview
Implement Bible Navigation with the following features:
1. Display all 66 books of the Bible in canonical order.
2. When a book is tapped, show a list of chapters in that book.
3. When a chapter is tapped, display the entire chapter text, not just one verse.

## Steps
- [x] Step 1: Modify BibleService to return books in canonical order for Old and New Testament.
- [x] Step 2: Modify BibleScreen's _buildVersesList() to display the entire chapter text as a single block without verse numbers.
- [x] Step 3: Test the navigation flow from books -> chapters -> chapter text.
- [x] Step 4: Verify all 66 books are displayed in order.

## Dependent Files
- lib/services/bible_service.dart
- lib/bible_screen.dart

## Notes
- Ensure the JSON data is loaded correctly.
- Test with different translations (KJV, NIV, ESV).
- Check for any UI/UX improvements needed.
