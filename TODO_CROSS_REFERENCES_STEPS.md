# TODO: Implement Cross-References in Verse View

## Steps
- [ ] Add Map<int, List<String>> _chapterCrossReferences variable to store cross-references for each verse in the chapter
- [ ] Add method _loadChapterCrossReferences() to load cross-references for all verses in the current chapter
- [ ] Modify _buildVersesList to add toggle button in header for showing/hiding cross-references
- [ ] Add collapsible cross-references section below verses list when _showCrossReferences is true
- [ ] Make cross-reference items clickable to navigate to referenced verses
- [ ] Update _navigateToVerse to not automatically set _showCrossReferences
- [ ] Test navigation and UI
