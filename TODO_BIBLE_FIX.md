# Bible App Fix and UI Redesign Plan

## Current Issues
- Old Testament only shows partial data (e.g., Genesis shows just 3 lines)
- New Testament displays as black screen
- Line-by-line verse display instead of traditional Bible layout
- No proper book/chapter navigation

## Goals
- Fix data loading for both Old and New Testaments
- Redesign UI to traditional Bible layout
- Add navigation sidebar/dropdown
- Ensure full book content loads with scrollable chapters
- Clean typography and spacing

## Implementation Steps

### Phase 1: Data Loading Fixes
1. [ ] Analyze BibleService data loading logic
2. [ ] Fix Old Testament partial data loading
3. [ ] Fix New Testament black screen issue
4. [ ] Ensure all books load complete content
5. [ ] Test data loading for all translations (KJV, NIV, ESV)

### Phase 2: UI Redesign
6. [ ] Create new BibleScreen layout with sidebar navigation
7. [ ] Implement book selection dropdown/sidebar
8. [ ] Implement chapter selection
9. [ ] Create scrollable chapter view with all verses
10. [ ] Add clean typography and spacing
11. [ ] Remove line-by-line display

### Phase 3: Navigation and Features
12. [ ] Add book/chapter navigation controls
13. [ ] Implement smooth scrolling between chapters
14. [ ] Add verse highlighting and selection
15. [ ] Integrate bookmarks, notes, daily verse navigation

### Phase 4: Testing and Polish
16. [ ] Test all books load completely
17. [ ] Verify Old/New Testament switching
18. [ ] Test navigation performance
19. [ ] Polish UI/UX
20. [ ] Handle edge cases and error states

## Technical Details
- Current: Tab-based navigation with grid layouts
- Target: Sidebar/dropdown navigation with scrollable content
- Data: JSON files in assets (bible_kjv.json, bible_niv.json, bible_esv.json)
- Service: BibleService handles data loading and filtering
