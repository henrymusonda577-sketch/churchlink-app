# TODO: Implement Cross-References in Verse View

## Overview
Add cross-reference display and navigation functionality to the Bible verse view, allowing users to see and navigate to related verses.

## Tasks
- [ ] Add cross-references toggle button in verse view header
- [ ] Display cross-references as a collapsible list below verses
- [ ] Make cross-reference items clickable to navigate to referenced verses
- [ ] Update UI to show cross-references only when available
- [ ] Test navigation between cross-referenced verses

## Files to Edit
- flutter_projects/my_flutter_app/lib/bible_screen.dart

## Technical Details
- Use existing _crossReferences list and _showCrossReferences flag
- Add navigation logic similar to _navigateToVerse
- Style consistently with existing UI (night mode support)
- Handle cases where no cross-references exist
