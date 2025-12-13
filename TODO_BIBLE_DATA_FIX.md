# Bible Data Fix Plan

## Current Issues
- NIV file only contains first verse of each chapter
- ESV file has incorrect structure (Acts marked as Old Testament, empty chapters)
- KJV file appears complete but needs verification

## Tasks
- [x] Analyze KJV file structure and completeness
- [x] Fix NIV file with complete chapter data
- [x] Fix ESV file structure and data
- [x] Verify all translations have consistent structure
- [x] Test Bible service with fixed data

## Data Structure Requirements
Each translation should have:
```
{
  "books": {
    "BookName": {
      "testament": "Old Testament" | "New Testament",
      "chapters": {
        "1": ["verse1", "verse2", ...],
        "2": ["verse1", "verse2", ...],
        ...
      }
    }
  }
}
