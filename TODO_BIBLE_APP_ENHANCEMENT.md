# TODO: Bible App Enhancement

## Overview
Enhance the Bible screen to function like a full Bible app with expanded data, search, bookmarks, notes, and more features.

## Steps to Complete

### Phase 1: Data Expansion and Service Creation
- [x] Create bible_service.dart for Bible data management, bookmarks, and notes
- [x] Add Bible data JSON file to assets with more books, chapters, and verses
- [x] Update pubspec.yaml to include the JSON asset
- [x] Load Bible data from JSON in the service

### Phase 2: Core Features Implementation
- [x] Implement search functionality in bible_screen.dart (keyword and reference search)
- [x] Add bookmarks feature (save favorite verses to Firestore)
- [x] Add notes feature (add personal notes to verses, stored in Firestore)
- [x] Add share functionality for verses

### Phase 3: UI Enhancements
- [x] Add font size adjustment controls
- [x] Add night mode toggle
- [x] Improve verse display with better formatting
- [x] Add verse highlighting and selection

### Phase 4: Additional Features
- [x] Implement daily Bible verse feature (random verse from Bible data)
- [x] Add verse history/recently viewed
- [x] Add reading plans feature
- [x] Add audio Bible playback (implemented using text-to-speech)

### Phase 5: Testing and Polish
- [x] Test all navigation and features
- [x] Ensure data loads correctly
- [x] Polish UI and user experience

## Files to Edit/Create
- flutter_projects/my_flutter_app/lib/services/bible_service.dart (NEW)
- flutter_projects/my_flutter_app/assets/bible_data.json (NEW)
- flutter_projects/my_flutter_app/pubspec.yaml
- flutter_projects/my_flutter_app/lib/bible_screen.dart

## Technical Requirements
- Use Firestore for user-specific data (bookmarks, notes)
- Load Bible data from JSON asset for performance
- Implement efficient search algorithms
- Ensure offline functionality for Bible reading
