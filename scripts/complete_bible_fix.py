#!/usr/bin/env python3
"""
Complete Bible Data Fix Script
Adds all missing books, chapters, and verses to the Bible navigator
"""

import json
import os

# Complete Bible structure with canonical chapter counts
BIBLE_STRUCTURE = {
    # Old Testament (39 books)
    "Genesis": {"testament": "Old Testament", "chapters": 50},
    "Exodus": {"testament": "Old Testament", "chapters": 40},
    "Leviticus": {"testament": "Old Testament", "chapters": 27},
    "Numbers": {"testament": "Old Testament", "chapters": 36},
    "Deuteronomy": {"testament": "Old Testament", "chapters": 34},
    "Joshua": {"testament": "Old Testament", "chapters": 24},
    "Judges": {"testament": "Old Testament", "chapters": 21},
    "Ruth": {"testament": "Old Testament", "chapters": 4},
    "1 Samuel": {"testament": "Old Testament", "chapters": 31},
    "2 Samuel": {"testament": "Old Testament", "chapters": 24},
    "1 Kings": {"testament": "Old Testament", "chapters": 22},
    "2 Kings": {"testament": "Old Testament", "chapters": 25},
    "1 Chronicles": {"testament": "Old Testament", "chapters": 29},
    "2 Chronicles": {"testament": "Old Testament", "chapters": 36},
    "Ezra": {"testament": "Old Testament", "chapters": 10},
    "Nehemiah": {"testament": "Old Testament", "chapters": 13},
    "Esther": {"testament": "Old Testament", "chapters": 10},
    "Job": {"testament": "Old Testament", "chapters": 42},
    "Psalms": {"testament": "Old Testament", "chapters": 150},
    "Proverbs": {"testament": "Old Testament", "chapters": 31},
    "Ecclesiastes": {"testament": "Old Testament", "chapters": 12},
    "Song of Solomon": {"testament": "Old Testament", "chapters": 8},
    "Isaiah": {"testament": "Old Testament", "chapters": 66},
    "Jeremiah": {"testament": "Old Testament", "chapters": 52},
    "Lamentations": {"testament": "Old Testament", "chapters": 5},
    "Ezekiel": {"testament": "Old Testament", "chapters": 48},
    "Daniel": {"testament": "Old Testament", "chapters": 12},
    "Hosea": {"testament": "Old Testament", "chapters": 14},
    "Joel": {"testament": "Old Testament", "chapters": 3},
    "Amos": {"testament": "Old Testament", "chapters": 9},
    "Obadiah": {"testament": "Old Testament", "chapters": 1},
    "Jonah": {"testament": "Old Testament", "chapters": 4},
    "Micah": {"testament": "Old Testament", "chapters": 7},
    "Nahum": {"testament": "Old Testament", "chapters": 3},
    "Habakkuk": {"testament": "Old Testament", "chapters": 3},
    "Zephaniah": {"testament": "Old Testament", "chapters": 3},
    "Haggai": {"testament": "Old Testament", "chapters": 2},
    "Zechariah": {"testament": "Old Testament", "chapters": 14},
    "Malachi": {"testament": "Old Testament", "chapters": 4},
    
    # New Testament (27 books)
    "Matthew": {"testament": "New Testament", "chapters": 28},
    "Mark": {"testament": "New Testament", "chapters": 16},
    "Luke": {"testament": "New Testament", "chapters": 24},
    "John": {"testament": "New Testament", "chapters": 21},
    "Acts": {"testament": "New Testament", "chapters": 28},
    "Romans": {"testament": "New Testament", "chapters": 16},
    "1 Corinthians": {"testament": "New Testament", "chapters": 16},
    "2 Corinthians": {"testament": "New Testament", "chapters": 13},
    "Galatians": {"testament": "New Testament", "chapters": 6},
    "Ephesians": {"testament": "New Testament", "chapters": 6},
    "Philippians": {"testament": "New Testament", "chapters": 4},
    "Colossians": {"testament": "New Testament", "chapters": 4},
    "1 Thessalonians": {"testament": "New Testament", "chapters": 5},
    "2 Thessalonians": {"testament": "New Testament", "chapters": 3},
    "1 Timothy": {"testament": "New Testament", "chapters": 6},
    "2 Timothy": {"testament": "New Testament", "chapters": 4},
    "Titus": {"testament": "New Testament", "chapters": 3},
    "Philemon": {"testament": "New Testament", "chapters": 1},
    "Hebrews": {"testament": "New Testament", "chapters": 13},
    "James": {"testament": "New Testament", "chapters": 5},
    "1 Peter": {"testament": "New Testament", "chapters": 5},
    "2 Peter": {"testament": "New Testament", "chapters": 3},
    "1 John": {"testament": "New Testament", "chapters": 5},
    "2 John": {"testament": "New Testament", "chapters": 1},
    "3 John": {"testament": "New Testament", "chapters": 1},
    "Jude": {"testament": "New Testament", "chapters": 1},
    "Revelation": {"testament": "New Testament", "chapters": 22}
}

def load_json_file(filepath):
    """Load JSON file safely"""
    try:
        with open(filepath, 'r', encoding='utf-8-sig') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading {filepath}: {e}")
        return None

def save_json_file(filepath, data):
    """Save JSON file safely"""
    try:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"Successfully saved {filepath}")
        return True
    except Exception as e:
        print(f"Error saving {filepath}: {e}")
        return False

def create_placeholder_verses(num_verses):
    """Create placeholder verses for missing chapters"""
    verses = []
    for i in range(1, num_verses + 1):
        verses.append(f"Verse {i} - This verse is being loaded. Please check back later for complete text.")
    return verses

def get_verse_counts():
    """Get approximate verse counts for each chapter (simplified)"""
    # This is a simplified approach - in reality, verse counts vary significantly
    # For now, we'll use average estimates
    return {
        "short": 15,    # Short chapters (like Psalms, Proverbs)
        "medium": 25,   # Medium chapters
        "long": 35      # Long chapters
    }

def estimate_verses_for_chapter(book_name, chapter_num, total_chapters):
    """Estimate number of verses for a chapter"""
    verse_counts = get_verse_counts()
    
    # Special cases for books with known patterns
    if book_name == "Psalms":
        return verse_counts["short"]
    elif book_name in ["Genesis", "Exodus", "Numbers", "Deuteronomy"]:
        return verse_counts["long"]
    elif book_name in ["1 Chronicles", "2 Chronicles", "Isaiah", "Jeremiah", "Ezekiel"]:
        return verse_counts["long"]
    elif book_name in ["Matthew", "Mark", "Luke", "John", "Acts"]:
        return verse_counts["long"]
    else:
        return verse_counts["medium"]

def fix_bible_data(bible_data):
    """Fix Bible data by adding missing books, chapters, and verses"""
    print("Fixing Bible data...")
    
    if "books" not in bible_data:
        bible_data["books"] = {}
    
    books_added = 0
    chapters_added = 0
    
    for book_name, book_info in BIBLE_STRUCTURE.items():
        if book_name not in bible_data["books"]:
            print(f"Adding missing book: {book_name}")
            bible_data["books"][book_name] = {
                "testament": book_info["testament"],
                "chapters": {}
            }
            books_added += 1
        
        book_data = bible_data["books"][book_name]
        
        # Ensure testament is set
        if "testament" not in book_data:
            book_data["testament"] = book_info["testament"]
        
        # Ensure chapters exist
        if "chapters" not in book_data:
            book_data["chapters"] = {}
        
        # Add missing chapters
        for chapter_num in range(1, book_info["chapters"] + 1):
            chapter_key = str(chapter_num)
            if chapter_key not in book_data["chapters"]:
                print(f"Adding missing chapter: {book_name} {chapter_num}")
                
                # Estimate verses for this chapter
                estimated_verses = estimate_verses_for_chapter(book_name, chapter_num, book_info["chapters"])
                verses = create_placeholder_verses(estimated_verses)
                
                book_data["chapters"][chapter_key] = verses
                chapters_added += 1
            else:
                # Check if chapter has verses
                if not book_data["chapters"][chapter_key] or len(book_data["chapters"][chapter_key]) == 0:
                    print(f"Adding verses to empty chapter: {book_name} {chapter_num}")
                    estimated_verses = estimate_verses_for_chapter(book_name, chapter_num, book_info["chapters"])
                    verses = create_placeholder_verses(estimated_verses)
                    book_data["chapters"][chapter_key] = verses
    
    print(f"Added {books_added} books and {chapters_added} chapters")
    return bible_data

def verify_bible_structure(bible_data):
    """Verify the Bible structure is complete"""
    print("\nVerifying Bible structure...")
    
    missing_books = []
    incomplete_books = []
    
    for book_name, book_info in BIBLE_STRUCTURE.items():
        if book_name not in bible_data["books"]:
            missing_books.append(book_name)
        else:
            book_data = bible_data["books"][book_name]
            expected_chapters = book_info["chapters"]
            actual_chapters = len(book_data.get("chapters", {}))
            
            if actual_chapters != expected_chapters:
                incomplete_books.append(f"{book_name} ({actual_chapters}/{expected_chapters} chapters)")
    
    if missing_books:
        print(f"Missing books: {missing_books}")
    
    if incomplete_books:
        print(f"Incomplete books: {incomplete_books}")
    
    if not missing_books and not incomplete_books:
        print("✓ Bible structure is complete!")
        return True
    
    return False

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    assets_dir = os.path.join(script_dir, '..', 'assets')
    
    # File paths
    kjv_file = os.path.join(assets_dir, 'bible_kjv.json')
    niv_file = os.path.join(assets_dir, 'bible_niv.json')
    esv_file = os.path.join(assets_dir, 'bible_esv.json')
    
    # Process each Bible translation
    for file_path, translation in [(kjv_file, 'KJV'), (niv_file, 'NIV'), (esv_file, 'ESV')]:
        print(f"\n{'='*50}")
        print(f"Processing {translation} Bible")
        print(f"{'='*50}")
        
        # Load existing data
        bible_data = load_json_file(file_path)
        if bible_data is None:
            print(f"Creating new {translation} Bible data...")
            bible_data = {"books": {}}
        
        # Fix the data
        fixed_data = fix_bible_data(bible_data)
        
        # Verify structure
        is_complete = verify_bible_structure(fixed_data)
        
        # Save the fixed data
        if save_json_file(file_path, fixed_data):
            print(f"✓ {translation} Bible data updated successfully")
        else:
            print(f"✗ Failed to save {translation} Bible data")
    
    print(f"\n{'='*50}")
    print("Bible data fix completed!")
    print("All missing books, chapters, and verses have been added.")
    print("Note: Placeholder text has been used for missing verses.")
    print("You may want to replace these with actual Bible text later.")
    print(f"{'='*50}")

if __name__ == "__main__":
    main()