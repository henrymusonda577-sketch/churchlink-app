# TODO: Bible App Enhancement

## Overview
Enhance the existing Bible tab to function like a full modern Bible app with advanced features.

## Steps to Complete

### Phase 1: Advanced Search & Filtering
- [ ] Add search filters for Testament (Old/New) and Book
- [ ] Implement advanced search UI with filter chips
- [ ] Update search results to show context and highlights

### Phase 2: Multiple Bible Translations
- [x] Add support for multiple translations (KJV, NIV, ESV)
- [x] Create translation selection dropdown
- [x] Add translation data files (KJV, NIV, ESV JSON)
- [x] Update BibleService to handle multiple translations
- [x] Store user preference for default translation

### Phase 3: Cross-References
- [ ] Add cross-reference data structure
- [ ] Implement cross-reference lookup functionality
- [ ] Add cross-reference display in verse view
- [ ] Add navigation to cross-referenced verses

### Phase 4: Recent Verses History
- [ ] Add recent verses tracking to Firestore
- [ ] Create recent verses screen/widget
- [ ] Add "Recently Viewed" option to menu
- [ ] Display list of recent verses with timestamps

### Phase 5: Enhanced Navigation & UX
- [ ] Add smooth page transitions between books/chapters
- [ ] Improve verse selection with better highlighting
- [ ] Add swipe gestures for chapter navigation
- [ ] Implement better loading states and animations

### Phase 6: Study Tools Enhancement
- [ ] Add inline commentary toggle (if commentary data available)
- [ ] Improve bookmark/note linking to specific verses
- [ ] Add verse comparison feature
- [ ] Enhance sharing with verse formatting

### Phase 7: Technical Improvements
- [ ] Optimize data loading and caching
- [ ] Add offline reading capability
- [ ] Improve mobile responsiveness
- [ ] Add accessibility features

## Files to Edit/Create
- flutter_projects/my_flutter_app/lib/bible_screen.dart (major updates)
- flutter_projects/my_flutter_app/lib/services/bible_service.dart (add translation support, cross-references, history)
- flutter_projects/my_flutter_app/assets/bible_kjv.json (NEW)
- flutter_projects/my_flutter_app/assets/bible_niv.json (NEW)
- flutter_projects/my_flutter_app/assets/bible_esv.json (NEW)
- flutter_projects/my_flutter_app/assets/cross_references.json (NEW)
- flutter_projects/my_flutter_app/pubspec.yaml (update assets)

## Technical Requirements
- Maintain backward compatibility with existing bookmarks/notes
- Ensure fast loading with large JSON files
- Implement efficient search algorithms
- Add proper error handling for missing data
- Maintain user preferences across sessions
