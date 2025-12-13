# Bible Chapters and Verses Fix

## Tasks
- [x] Run PowerShell script to update ESV data from Project Gutenberg
- [x] Create Python script to fetch NIV data from bible-api.com
- [x] Run Python script to update NIV JSON with complete chapters and verses
- [x] Verify all books in NIV and ESV have complete canonical chapters and verses
- [x] Test Bible screen navigation to ensure all chapters load properly

## Notes
- ESV: Use existing fetch_bible_data.ps1 script
- NIV: Create new script using bible-api.com (free API)
- Ensure JSON structure matches existing format
- All 66 books should have correct number of chapters and verses
