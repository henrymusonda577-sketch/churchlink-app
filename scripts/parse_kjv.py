#!/usr/bin/env python3
"""
Script to parse KJV Bible from local KJV.txt file into structured JSON
"""

import json
import re
import os

def parse_kjv(text):
    """Parse KJV text into structured data"""
    lines = text.split('\n')
    bible_data = {"books": []}

    books = [
        "Genesis","Exodus","Leviticus","Numbers","Deuteronomy","Joshua","Judges","Ruth",
        "1 Samuel","2 Samuel","1 Kings","2 Kings","1 Chronicles","2 Chronicles","Ezra","Nehemiah",
        "Esther","Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon","Isaiah","Jeremiah",
        "Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos","Obadiah","Jonah","Micah",
        "Nahum","Habakkuk","Zephaniah","Haggai","Zechariah","Malachi","Matthew","Mark",
        "Luke","John","Acts","Romans","1 Corinthians","2 Corinthians","Galatians","Ephesians",
        "Philippians","Colossians","1 Thessalonians","2 Thessalonians","1 Timothy","2 Timothy",
        "Titus","Philemon","Hebrews","James","1 Peter","2 Peter","1 John","2 John","3 John",
        "Jude","Revelation"
    ]

    current_book = None
    current_chapter = None
    current_verses = []
    current_verse_text = ""
    current_book_data = None
    current_chapter_data = None

    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
            continue

        # Check for book start
        book_found = None
        if not re.match(r'^\d+:\d+', line):  # not starting with verse
            for book in books:
                if book.lower() in line.lower():
                    book_found = book
                    break

        if book_found:
            # Save previous chapter
            if current_chapter_data and current_verses:
                current_chapter_data["verses"] = current_verses
                current_book_data["chapters"].append(current_chapter_data)

            # Save previous book
            if current_book_data:
                bible_data["books"].append(current_book_data)

            testament = "Old Testament" if books.index(book_found) < 39 else "New Testament"
            current_book_data = {"name": book_found, "testament": testament, "chapters": []}
            current_book = book_found
            current_chapter = None
            current_verses = []
            current_verse_text = ""
            current_chapter_data = None
            print(f"Found book: {current_book}")
            i += 1
            continue

        # Check for verses
        if current_book:
            if re.match(r'^\d+:\d+', line):
                # New verse
                if current_verse_text:
                    current_verses.append(current_verse_text.strip())
                match = re.match(r'(\d+):(\d+)\s+(.+)', line)
                if match:
                    chapter_num = int(match.group(1))
                    verse_num = int(match.group(2))
                    verse_text = match.group(3)

                    if chapter_num != current_chapter:
                        # Save previous chapter
                        if current_chapter_data and current_verses:
                            current_chapter_data["verses"] = current_verses
                            current_book_data["chapters"].append(current_chapter_data)

                        current_chapter = chapter_num
                        current_verses = []
                        current_verse_text = ""
                        current_chapter_data = {"number": chapter_num, "verses": []}

                    current_verse_text = verse_text
            else:
                # Continuation of current verse
                if current_verse_text:
                    current_verse_text += " " + line.strip()
        i += 1

    # Save last verse
    if current_verse_text:
        current_verses.append(current_verse_text.strip())

    # Save last chapter
    if current_chapter_data and current_verses:
        current_chapter_data["verses"] = current_verses
        current_book_data["chapters"].append(current_chapter_data)

    # Save last book
    if current_book_data:
        bible_data["books"].append(current_book_data)

    return bible_data

def main():
    kjv_path = "KJV.txt"
    if not os.path.exists(kjv_path):
        print(f"Error: {kjv_path} not found")
        return

    print("Reading KJV text...")
    with open(kjv_path, 'r', encoding='utf-8') as f:
        text = f.read()

    print("Parsing text...")
    bible_data = parse_kjv(text)

    output_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../assets/bible_kjv.json")
    print(f"Saving to {output_path}")
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(bible_data, f, indent=2, ensure_ascii=False)

    print("Done!")

if __name__ == "__main__":
    main()
