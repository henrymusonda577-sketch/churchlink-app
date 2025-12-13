#!/usr/bin/env python3
"""
Script to fetch complete NIV Bible data from bible-api.com
"""

import json
import os
import requests
import time

# Bible structure with chapter counts
BIBLE_STRUCTURE = {
    "Genesis": 50, "Exodus": 40, "Leviticus": 27, "Numbers": 36, "Deuteronomy": 34,
    "Joshua": 24, "Judges": 21, "Ruth": 4, "1 Samuel": 31, "2 Samuel": 24,
    "1 Kings": 22, "2 Kings": 25, "1 Chronicles": 29, "2 Chronicles": 36,
    "Ezra": 10, "Nehemiah": 13, "Esther": 10, "Job": 42, "Psalms": 150,
    "Proverbs": 31, "Ecclesiastes": 12, "Song of Solomon": 8, "Isaiah": 66,
    "Jeremiah": 52, "Lamentations": 5, "Ezekiel": 48, "Daniel": 12,
    "Hosea": 14, "Joel": 3, "Amos": 9, "Obadiah": 1, "Jonah": 4,
    "Micah": 7, "Nahum": 3, "Habakkuk": 3, "Zephaniah": 3, "Haggai": 2,
    "Zechariah": 14, "Malachi": 4, "Matthew": 28, "Mark": 16, "Luke": 24,
    "John": 21, "Acts": 28, "Romans": 16, "1 Corinthians": 16, "2 Corinthians": 13,
    "Galatians": 6, "Ephesians": 6, "Philippians": 4, "Colossians": 4,
    "1 Thessalonians": 5, "2 Thessalonians": 3, "1 Timothy": 6, "2 Timothy": 4,
    "Titus": 3, "Philemon": 1, "Hebrews": 13, "James": 5, "1 Peter": 5,
    "2 Peter": 3, "1 John": 5, "2 John": 1, "3 John": 1, "Jude": 1, "Revelation": 22
}

def get_book_abbrev(book_name):
    """Convert book name to API abbreviation"""
    abbrevs = {
        "1 Samuel": "1SA", "2 Samuel": "2SA", "1 Kings": "1KI", "2 Kings": "2KI",
        "1 Chronicles": "1CH", "2 Chronicles": "2CH", "1 Corinthians": "1CO",
        "2 Corinthians": "2CO", "1 Thessalonians": "1TH", "2 Thessalonians": "2TH",
        "1 Timothy": "1TI", "2 Timothy": "2TI", "1 Peter": "1PE", "2 Peter": "2PE",
        "1 John": "1JO", "2 John": "2JO", "3 John": "3JO", "Song of Solomon": "SNG",
        "Ecclesiastes": "ECC", "Psalms": "PSA"
    }
    return abbrevs.get(book_name, book_name[:3].upper())

def fetch_chapter(book, chapter):
    """Fetch a chapter from bible-api.com"""
    abbrev = get_book_abbrev(book)
    url = f"https://bible-api.com/{abbrev}{chapter}?translation=niv"

    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            data = response.json()
            if 'verses' in data:
                verses = []
                for verse in data['verses']:
                    verses.append(verse['text'].strip())
                return verses
        print(f"Failed to fetch {book} {chapter}: {response.status_code}")
    except Exception as e:
        print(f"Error fetching {book} {chapter}: {e}")

    return None

def main():
    print("Fetching complete NIV Bible data from bible-api.com...")

    bible_data = {"books": {}}

    for book_name, chapter_count in BIBLE_STRUCTURE.items():
        print(f"Processing {book_name}...")
        testament = "Old Testament" if list(BIBLE_STRUCTURE.keys()).index(book_name) < 39 else "New Testament"

        book_data = {
            "testament": testament,
            "chapters": {}
        }

        for chapter in range(1, chapter_count + 1):
            verses = fetch_chapter(book_name, chapter)
            if verses:
                book_data["chapters"][str(chapter)] = verses
                print(f"  ✓ Chapter {chapter} ({len(verses)} verses)")
            else:
                print(f"  ✗ Failed to fetch Chapter {chapter}")
                # Add placeholder
                book_data["chapters"][str(chapter)] = [f"Verse 1 - NIV text for {book_name} {chapter}:1 not available."]

            time.sleep(0.1)  # Rate limiting

        bible_data["books"][book_name] = book_data

    # Save to file
    output_path = os.path.join(os.path.dirname(__file__), '..', 'assets', 'bible_niv.json')
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(bible_data, f, indent=2, ensure_ascii=False)

    print(f"NIV Bible data saved to {output_path}")

if __name__ == "__main__":
    main()