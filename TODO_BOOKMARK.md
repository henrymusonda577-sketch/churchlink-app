# TODO: Add Bookmark Feature to BibleVerseScreen

## Steps to Complete
- [x] Add state for bookmarked verses: Set<String> _bookmarkedVerses in _BibleVerseScreenState
- [x] Load bookmarks from SharedPreferences in initState using key '${bookName}_${chapterNumber}_bookmarks'
- [x] Save bookmarks to SharedPreferences in dispose or when toggled
- [x] Add IconButton for bookmarking next to each verse in the Row
- [x] Add "View Bookmarks" to the PopupMenuButton in appBar actions
- [x] Implement _showBookmarksDialog: show bottom sheet with list of bookmarked verses; tapping scrolls to verse
- [x] Make verse text tappable: wrap Text in GestureDetector, onTap shows a dialog with the full verse text
- [ ] Test the feature: bookmark verses, view bookmarks, tap verses to open dialog
