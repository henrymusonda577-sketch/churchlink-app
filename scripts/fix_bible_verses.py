#!/usr/bin/env python3
"""
Script to fix Bible verse data by replacing placeholder text with actual KJV verses
"""

import json
import re
import os

def parse_kjv_text(text):
    """Parse KJV text and return a dictionary of verses organized by book, chapter, verse"""
    lines = text.split('\n')
    bible_data = {}

    current_book = None
    current_chapter = None

    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
            continue

        # Skip header lines
        if line.startswith('***') or 'GUTENBERG' in line.upper() or 'PROJECT' in line.upper():
            i += 1
            continue

        # Check for book start
        book_names = [
            "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth",
            "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah",
            "Esther", "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah",
            "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah",
            "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi", "Matthew", "Mark",
            "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
            "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy",
            "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
            "Jude", "Revelation"
        ]

        book_found = None
        for book in book_names:
            if book.lower() in line.lower() and ('book of' in line.lower() or 'gospel' in line.lower() or line.lower().strip() == book.lower()):
                book_found = book
                break

        if book_found:
            current_book = book_found
            bible_data[current_book] = {}
            print(f"Processing book: {current_book}")
            i += 1
            continue

        # Check for verses
        if current_book and re.match(r'^\d+:\d+', line):
            match = re.match(r'(\d+):(\d+)\s+(.+)', line)
            if match:
                chapter_num = int(match.group(1))
                verse_num = int(match.group(2))
                verse_text = match.group(3).strip()

                if chapter_num not in bible_data[current_book]:
                    bible_data[current_book][chapter_num] = {}

                # Handle multi-line verses
                while i + 1 < len(lines) and lines[i + 1].strip() and not re.match(r'^\d+:\d+', lines[i + 1].strip()):
                    i += 1
                    next_line = lines[i].strip()
                    if next_line:
                        verse_text += " " + next_line

                bible_data[current_book][chapter_num][verse_num] = verse_text

        i += 1

    return bible_data

def is_placeholder_verse(verse_text):
    """Check if verse text is a placeholder"""
    return "verse is being loaded" in verse_text.lower() or "please check back later" in verse_text.lower()

def update_bible_json(kjv_data, json_file_path):
    """Update a Bible JSON file with real verse content from KJV data"""
    print(f"Updating {json_file_path}...")

    # Load existing JSON
    with open(json_file_path, 'r', encoding='utf-8') as f:
        bible_json = json.load(f)

    updated_count = 0

    # Update each book
    for book_name, book_data in bible_json['books'].items():
        if book_name in kjv_data:
            kjv_book = kjv_data[book_name]

            for chapter_key, verses_array in book_data['chapters'].items():
                chapter_num = int(chapter_key)

                if chapter_num in kjv_book:
                    kjv_chapter = kjv_book[chapter_num]

                    # Update each verse in the array
                    for verse_index in range(len(verses_array)):
                        verse_num = verse_index + 1  # Verses are 1-indexed

                        if verse_num in kjv_chapter:
                            current_text = verses_array[verse_index]

                            # Only update if it's a placeholder
                            if is_placeholder_verse(current_text):
                                new_text = kjv_chapter[verse_num]
                                verses_array[verse_index] = new_text
                                updated_count += 1
                                print(f"  Updated {book_name} {chapter_num}:{verse_num}")

    # Save updated JSON
    with open(json_file_path, 'w', encoding='utf-8') as f:
        json.dump(bible_json, f, indent=2, ensure_ascii=False)

    print(f"Updated {updated_count} verses in {json_file_path}")
    return updated_count

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    kjv_path = os.path.join(script_dir, 'KJV.txt')
    assets_dir = os.path.join(script_dir, '..', 'assets')

    # Check if KJV file exists
    if not os.path.exists(kjv_path):
        print(f"Error: KJV.txt not found at {kjv_path}")
        return

    print("Parsing KJV text file...")
    with open(kjv_path, 'r', encoding='utf-8') as f:
        kjv_text = f.read()

    kjv_data = parse_kjv_text(kjv_text)
    print(f"Parsed {len(kjv_data)} books from KJV text")

    # Update each Bible translation
    translations = [
        ('bible_kjv.json', 'KJV'),
        ('bible_niv.json', 'NIV'),
        ('bible_esv.json', 'ESV')
    ]

    total_updated = 0
    for filename, translation in translations:
        json_path = os.path.join(assets_dir, filename)
        if os.path.exists(json_path):
            updated = update_bible_json(kjv_data, json_path)
            total_updated += updated
        else:
            print(f"Warning: {json_path} not found")

    print(f"\nCompleted! Updated {total_updated} verses total.")

if __name__ == "__main__":
    main()