#!/usr/bin/env python3
"""
Script to fetch and parse KJV Bible from Project Gutenberg
"""

import urllib.request
import json
import re
import os

def download_text(url):
    """Download text from URL"""
    with urllib.request.urlopen(url) as response:
        return response.read().decode('utf-8')

def parse_kjv(text):
    """Parse KJV text into structured data"""
    lines = text.split('\n')
    bible_data = {"books": {}}

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

    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
            continue

        # Check for book start
        book_found = None
        for book in books:
            if book.lower() in line.lower():
                book_found = book
                break

        if book_found:
            # Save previous book/chapter
            if current_book and current_chapter and current_verses:
                if current_book not in bible_data["books"]:
                    testament = "Old Testament" if books.index(current_book) < 39 else "New Testament"
                    bible_data["books"][current_book] = {"testament": testament, "chapters": {}}
                bible_data["books"][current_book]["chapters"][str(current_chapter)] = current_verses

            current_book = book_found
            current_chapter = None
            current_verses = []
            print(f"Found book: {current_book}")
            i += 1
            continue

        # Check for verse
        match = re.match(r'^(\d+):(\d+)\s+(.+)$', line)
        if match:
            chapter_num = int(match.group(1))
            verse_num = int(match.group(2))
            verse_text = match.group(3).strip()

            if current_chapter != chapter_num:
                # Save previous chapter
                if current_book and current_chapter and current_verses:
                    if current_book not in bible_data["books"]:
                        testament = "Old Testament" if books.index(current_book) < 39 else "New Testament"
                        bible_data["books"][current_book] = {"testament": testament, "chapters": {}}
                    bible_data["books"][current_book]["chapters"][str(current_chapter)] = current_verses

                current_chapter = chapter_num
                current_verses = []

            current_verses.append(verse_text)
        i += 1

    # Save last chapter
    if current_book and current_chapter and current_verses:
        if current_book not in bible_data["books"]:
            testament = "Old Testament" if books.index(current_book) < 39 else "New Testament"
            bible_data["books"][current_book] = {"testament": testament, "chapters": {}}
        bible_data["books"][current_book]["chapters"][str(current_chapter)] = current_verses

    return bible_data

def main():
    url = "https://www.gutenberg.org/files/10/10-0.txt"
    print("Downloading KJV text...")
    text = download_text(url)

    # Save the raw text for parse_kjv.py
    with open('KJV.txt', 'w', encoding='utf-8') as f:
        f.write(text)

    print("Parsing text...")
    bible_data = parse_kjv(text)

    output_path = "../assets/bible_kjv.json"
    print(f"Saving to {output_path}")
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(bible_data, f, indent=2, ensure_ascii=False)

    print("Done!")

if __name__ == "__main__":
    main()
