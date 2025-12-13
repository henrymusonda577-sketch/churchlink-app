#!/usr/bin/env python3
"""
Complete Bible Structure Generator
Creates a complete Bible with all 66 books, proper chapter counts, and placeholder verses
"""

import json
import os

# Complete Bible structure with exact canonical chapter counts
COMPLETE_BIBLE_STRUCTURE = {
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

# Approximate verse counts for each chapter (simplified estimates)
VERSE_ESTIMATES = {
    # Old Testament books with typical verse counts
    "Genesis": [31, 25, 24, 26, 32, 22, 24, 22, 29, 32, 32, 20, 18, 24, 21, 16, 27, 33, 38, 18, 34, 24, 20, 67, 34, 35, 46, 22, 35, 43, 55, 32, 20, 31, 29, 43, 36, 30, 23, 23, 57, 38, 34, 34, 28, 34, 31, 22, 33, 26],
    "Exodus": [22, 25, 22, 31, 23, 30, 25, 32, 35, 29, 10, 51, 22, 31, 27, 36, 16, 27, 25, 26, 36, 31, 33, 18, 40, 37, 21, 43, 46, 38, 18, 35, 23, 35, 35, 38, 29, 31, 43, 38],
    "Leviticus": [17, 16, 17, 35, 19, 30, 38, 36, 24, 20, 47, 8, 59, 57, 33, 34, 16, 30, 37, 27, 24, 33, 44, 23, 55, 46, 34],
    "Numbers": [54, 34, 51, 49, 31, 27, 89, 26, 23, 36, 35, 16, 33, 45, 41, 50, 13, 32, 22, 29, 35, 41, 30, 25, 18, 65, 23, 31, 40, 16, 54, 42, 56, 29, 34, 13],
    "Deuteronomy": [46, 37, 29, 49, 33, 25, 26, 20, 29, 22, 32, 32, 18, 29, 23, 22, 20, 22, 21, 20, 23, 30, 25, 22, 19, 19, 26, 68, 29, 20, 30, 52, 29, 12],
    "Joshua": [18, 24, 17, 24, 15, 27, 26, 35, 27, 43, 23, 24, 33, 15, 63, 10, 18, 28, 51, 9, 45, 34, 16, 33],
    "Judges": [36, 23, 31, 24, 31, 40, 25, 35, 57, 18, 40, 15, 25, 20, 20, 31, 13, 31, 30, 48, 25],
    "Ruth": [22, 23, 18, 22],
    "1 Samuel": [28, 36, 21, 22, 12, 21, 17, 22, 27, 27, 15, 25, 23, 52, 35, 23, 58, 30, 24, 42, 15, 23, 29, 22, 44, 25, 12, 25, 11, 31, 13],
    "2 Samuel": [27, 32, 39, 12, 25, 23, 29, 18, 13, 19, 27, 31, 39, 33, 37, 23, 29, 33, 43, 26, 22, 51, 39, 25],
    "1 Kings": [53, 46, 28, 34, 18, 38, 51, 66, 28, 29, 43, 33, 34, 31, 34, 34, 24, 46, 21, 43, 29, 53],
    "2 Kings": [18, 25, 27, 44, 27, 33, 20, 29, 37, 36, 21, 21, 25, 29, 38, 20, 41, 37, 37, 21, 26, 20, 37, 20, 30],
    "1 Chronicles": [54, 55, 24, 43, 26, 81, 40, 40, 44, 14, 47, 40, 14, 17, 29, 43, 27, 17, 19, 8, 30, 19, 32, 31, 31, 32, 34, 21, 30],
    "2 Chronicles": [17, 18, 17, 22, 14, 42, 22, 18, 31, 19, 23, 16, 22, 15, 19, 14, 19, 34, 11, 37, 20, 12, 21, 27, 28, 23, 9, 27, 36, 27, 21, 33, 25, 33, 27, 23],
    "Ezra": [11, 70, 13, 24, 17, 22, 28, 36, 15, 44],
    "Nehemiah": [11, 20, 32, 23, 19, 19, 73, 18, 38, 39, 36, 47, 31],
    "Esther": [22, 23, 15, 17, 14, 14, 10, 17, 32, 3],
    "Job": [22, 13, 26, 21, 27, 30, 21, 22, 35, 22, 20, 25, 28, 22, 35, 22, 16, 21, 29, 29, 34, 30, 17, 25, 6, 14, 23, 28, 25, 31, 40, 22, 33, 37, 16, 33, 24, 41, 30, 24, 34, 17],
    "Psalms": [6, 12, 8, 8, 12, 10, 17, 9, 20, 18, 7, 8, 6, 7, 5, 11, 15, 50, 14, 9, 13, 31, 6, 10, 22, 12, 14, 9, 11, 12, 24, 11, 22, 22, 28, 12, 40, 22, 13, 17, 13, 11, 5, 26, 17, 11, 9, 14, 20, 23, 19, 9, 6, 7, 23, 13, 11, 11, 17, 12, 8, 12, 11, 10, 13, 20, 7, 35, 36, 5, 24, 20, 28, 23, 10, 12, 20, 72, 13, 19, 16, 8, 18, 12, 13, 17, 7, 18, 52, 17, 16, 15, 5, 23, 11, 13, 12, 9, 9, 7, 5, 8, 28, 22, 35, 45, 48, 43, 13, 31, 7, 10, 10, 9, 8, 18, 19, 2, 29, 176, 7, 8, 9, 4, 8, 5, 6, 5, 6, 8, 8, 3, 18, 3, 3, 21, 26, 9, 8, 24, 13, 10, 7, 12, 15, 21, 10, 20, 14, 9, 6],
    "Proverbs": [33, 22, 35, 27, 23, 35, 27, 36, 18, 32, 31, 28, 25, 35, 33, 33, 28, 24, 29, 30, 31],
    "Ecclesiastes": [18, 26, 22, 16, 20, 12, 29, 17, 18, 20, 10, 14],
    "Song of Solomon": [17, 17, 11, 16, 16, 13, 13, 14],
    "Isaiah": [31, 22, 26, 6, 30, 13, 25, 22, 21, 34, 16, 6, 22, 32, 9, 14, 14, 7, 25, 6, 17, 25, 18, 23, 12, 21, 13, 29, 24, 33, 9, 20, 24, 17, 10, 22, 38, 22, 8, 31, 29, 25, 28, 28, 25, 13, 15, 22, 26, 11, 23, 15, 12, 17, 13, 12, 21, 14, 21, 22, 11, 12, 19, 12, 25, 24],
    "Jeremiah": [19, 37, 25, 31, 31, 30, 34, 22, 26, 25, 23, 17, 27, 22, 21, 21, 27, 23, 15, 18, 14, 30, 40, 10, 38, 24, 22, 17, 32, 24, 40, 44, 26, 22, 19, 32, 21, 28, 18, 16, 18, 22, 13, 30, 5, 28, 7, 47, 39, 46, 64, 34],
    "Lamentations": [22, 22, 66, 22, 22],
    "Ezekiel": [28, 10, 27, 17, 17, 14, 27, 18, 11, 22, 25, 28, 23, 23, 8, 63, 24, 32, 14, 49, 32, 31, 49, 27, 17, 21, 36, 26, 21, 26, 18, 32, 33, 31, 15, 38, 28, 23, 29, 49, 26, 20, 27, 31, 25, 24, 23, 35],
    "Daniel": [21, 49, 30, 37, 31, 28, 28, 27, 27, 21, 45, 13],
    "Hosea": [11, 23, 5, 19, 15, 11, 16, 14, 17, 15, 12, 14, 16, 9],
    "Joel": [20, 32, 21],
    "Amos": [15, 16, 15, 13, 27, 14, 17, 14, 15],
    "Obadiah": [21],
    "Jonah": [17, 10, 10, 11],
    "Micah": [16, 13, 12, 13, 15, 16, 20],
    "Nahum": [15, 13, 19],
    "Habakkuk": [17, 20, 19],
    "Zephaniah": [18, 15, 20],
    "Haggai": [15, 23],
    "Zechariah": [21, 13, 10, 14, 11, 15, 14, 23, 17, 12, 17, 14, 9, 21],
    "Malachi": [14, 17, 18, 6],
    
    # New Testament books
    "Matthew": [25, 23, 17, 25, 48, 34, 29, 34, 38, 42, 30, 50, 58, 36, 39, 28, 27, 35, 30, 34, 46, 46, 39, 51, 46, 75, 66, 20],
    "Mark": [45, 28, 35, 41, 43, 56, 37, 38, 50, 52, 33, 44, 37, 72, 47, 20],
    "Luke": [80, 52, 38, 44, 39, 49, 50, 56, 62, 42, 54, 59, 35, 35, 32, 31, 37, 43, 48, 47, 38, 71, 56, 53],
    "John": [51, 25, 36, 54, 47, 71, 53, 59, 41, 42, 57, 50, 38, 31, 27, 33, 26, 40, 42, 31, 25],
    "Acts": [26, 47, 26, 37, 42, 15, 60, 40, 43, 48, 30, 25, 52, 28, 41, 40, 34, 28, 41, 38, 40, 30, 35, 27, 27, 32, 44, 31],
    "Romans": [32, 29, 31, 25, 21, 23, 25, 39, 33, 21, 36, 21, 14, 23, 33, 27],
    "1 Corinthians": [31, 16, 23, 21, 13, 20, 40, 13, 27, 33, 34, 31, 13, 40, 58, 24],
    "2 Corinthians": [24, 17, 18, 18, 21, 18, 16, 24, 15, 18, 33, 21, 14],
    "Galatians": [24, 21, 29, 31, 26, 18],
    "Ephesians": [23, 22, 21, 32, 33, 24],
    "Philippians": [30, 30, 21, 23],
    "Colossians": [29, 23, 25, 18],
    "1 Thessalonians": [10, 20, 13, 18, 28],
    "2 Thessalonians": [12, 17, 18],
    "1 Timothy": [20, 15, 16, 16, 25, 21],
    "2 Timothy": [18, 26, 17, 22],
    "Titus": [16, 15, 15],
    "Philemon": [25],
    "Hebrews": [14, 18, 19, 16, 14, 20, 28, 13, 28, 39, 40, 29, 25],
    "James": [27, 26, 18, 17, 20],
    "1 Peter": [25, 25, 22, 19, 14],
    "2 Peter": [21, 22, 18],
    "1 John": [10, 29, 24, 21, 21],
    "2 John": [13],
    "3 John": [14],
    "Jude": [25],
    "Revelation": [20, 29, 22, 11, 14, 17, 17, 13, 21, 11, 19, 17, 18, 20, 8, 21, 18, 24, 21, 15, 27, 21]
}

def create_placeholder_verses(book_name, chapter_num, verse_count):
    """Create placeholder verses for a chapter"""
    verses = []
    for i in range(1, verse_count + 1):
        if book_name == "Psalms":
            verses.append(f"Psalm {chapter_num}:{i} - This verse is being loaded. Please check back later for complete text.")
        else:
            verses.append(f"{book_name} {chapter_num}:{i} - This verse is being loaded. Please check back later for complete text.")
    return verses

def get_verse_count(book_name, chapter_num):
    """Get the verse count for a specific chapter"""
    if book_name in VERSE_ESTIMATES:
        verse_counts = VERSE_ESTIMATES[book_name]
        if chapter_num <= len(verse_counts):
            return verse_counts[chapter_num - 1]
    
    # Default estimates if not found
    if book_name == "Psalms":
        return 15  # Psalms are generally shorter
    elif book_name in ["Genesis", "Exodus", "Numbers", "Deuteronomy", "1 Chronicles", "2 Chronicles"]:
        return 35  # Longer historical books
    elif book_name in ["Matthew", "Mark", "Luke", "John", "Acts"]:
        return 40  # Gospels and Acts
    else:
        return 25  # Default

def create_complete_bible():
    """Create a complete Bible structure with all books and chapters"""
    bible_data = {"books": {}}
    
    for book_name, book_info in COMPLETE_BIBLE_STRUCTURE.items():
        print(f"Creating {book_name}...")
        
        bible_data["books"][book_name] = {
            "testament": book_info["testament"],
            "chapters": {}
        }
        
        # Create all chapters for this book
        for chapter_num in range(1, book_info["chapters"] + 1):
            verse_count = get_verse_count(book_name, chapter_num)
            verses = create_placeholder_verses(book_name, chapter_num, verse_count)
            bible_data["books"][book_name]["chapters"][str(chapter_num)] = verses
    
    return bible_data

def save_bible_files():
    """Save complete Bible files for all translations"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    assets_dir = os.path.join(script_dir, '..', 'assets')
    
    # Create complete Bible data
    print("Creating complete Bible structure...")
    complete_bible = create_complete_bible()
    
    # Save for each translation
    translations = ['kjv', 'niv', 'esv']
    
    for translation in translations:
        filename = f'bible_{translation}.json'
        filepath = os.path.join(assets_dir, filename)
        
        print(f"Saving {translation.upper()} Bible to {filename}...")
        
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(complete_bible, f, indent=2, ensure_ascii=False)
            print(f"✓ Successfully saved {filename}")
        except Exception as e:
            print(f"✗ Error saving {filename}: {e}")

def verify_bible_structure(bible_data):
    """Verify the Bible structure is complete"""
    print("\nVerifying Bible structure...")
    
    missing_books = []
    incomplete_books = []
    total_chapters = 0
    total_verses = 0
    
    for book_name, book_info in COMPLETE_BIBLE_STRUCTURE.items():
        if book_name not in bible_data["books"]:
            missing_books.append(book_name)
        else:
            book_data = bible_data["books"][book_name]
            expected_chapters = book_info["chapters"]
            actual_chapters = len(book_data.get("chapters", {}))
            total_chapters += actual_chapters
            
            if actual_chapters != expected_chapters:
                incomplete_books.append(f"{book_name} ({actual_chapters}/{expected_chapters} chapters)")
            
            # Count verses
            for chapter_verses in book_data.get("chapters", {}).values():
                total_verses += len(chapter_verses)
    
    print(f"Total books: {len(bible_data['books'])}/66")
    print(f"Total chapters: {total_chapters}")
    print(f"Total verses: {total_verses}")
    
    if missing_books:
        print(f"Missing books: {missing_books}")
    
    if incomplete_books:
        print(f"Incomplete books: {incomplete_books}")
    
    if not missing_books and not incomplete_books:
        print("✓ Bible structure is complete!")
        return True
    
    return False

def main():
    print("=" * 60)
    print("Complete Bible Structure Generator")
    print("=" * 60)
    
    # Create and save complete Bible files
    save_bible_files()
    
    # Verify one of the created files
    script_dir = os.path.dirname(os.path.abspath(__file__))
    assets_dir = os.path.join(script_dir, '..', 'assets')
    kjv_file = os.path.join(assets_dir, 'bible_kjv.json')
    
    try:
        with open(kjv_file, 'r', encoding='utf-8') as f:
            bible_data = json.load(f)
        verify_bible_structure(bible_data)
    except Exception as e:
        print(f"Error verifying Bible structure: {e}")
    
    print("\n" + "=" * 60)
    print("Bible structure generation completed!")
    print("All 66 books with proper chapter and verse counts have been added.")
    print("Note: Placeholder text has been used for verses.")
    print("You can replace these with actual Bible text later.")
    print("=" * 60)

if __name__ == "__main__":
    main()