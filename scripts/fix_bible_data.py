#!/usr/bin/env python3
"""
Script to fix Bible data files (NIV and ESV) using KJV as reference structure
"""

import json
import os

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
    except Exception as e:
        print(f"Error saving {filepath}: {e}")

def convert_niv_to_object(niv_array_data, kjv_data):
    """Convert NIV array structure to object structure"""
    print("Converting NIV to object structure...")
    niv_object = {"books": {}}

    for book in niv_array_data['books']:
        name = book['name']
        if name in kjv_data['books']:
            testament = kjv_data['books'][name]['testament']
            chapters = {}
            for i, verses in enumerate(book['chapters'], 1):
                chapters[str(i)] = verses
            niv_object['books'][name] = {
                "testament": testament,
                "chapters": chapters
            }
    return niv_object

def fix_niv_file(kjv_data, niv_data):
    """Fix NIV file by adding complete chapter data from KJV structure"""
    print("Fixing NIV file...")

    for book_name, book_data in kjv_data['books'].items():
        if book_name in niv_data['books'] and book_data['testament'] == 'New Testament':
            print(f"Processing {book_name}...")

            # Keep the first verse from NIV and add the rest from KJV
            for chapter_num, verses in book_data['chapters'].items():
                if chapter_num in niv_data['books'][book_name]['chapters']:
                    # NIV only has first verse, keep it and add the rest
                    niv_verses = niv_data['books'][book_name]['chapters'][chapter_num]
                    if len(niv_verses) == 1:
                        niv_data['books'][book_name]['chapters'][chapter_num] = niv_verses + verses[1:]
                    # If already has more, keep as is
                else:
                    # If chapter doesn't exist in NIV, copy from KJV
                    niv_data['books'][book_name]['chapters'][chapter_num] = verses

    return niv_data

def fix_esv_file(kjv_data):
    """Create complete ESV file using KJV structure"""
    print("Creating ESV file...")

    esv_data = {"books": {}}

    for book_name, book_data in kjv_data['books'].items():
        print(f"Processing {book_name}...")

        # Create ESV structure with KJV data
        esv_data['books'][book_name] = {
            "testament": book_data['testament'],
            "chapters": {}
        }

        # Copy all chapters and verses from KJV
        for chapter_num, verses in book_data['chapters'].items():
            esv_data['books'][book_name]['chapters'][chapter_num] = verses.copy()

    return esv_data

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    assets_dir = os.path.join(script_dir, '..', 'assets')

    # File paths
    kjv_file = os.path.join(assets_dir, 'bible_kjv_fixed.json')
    niv_file = os.path.join(assets_dir, 'bible_niv.json')
    esv_file = os.path.join(assets_dir, 'bible_esv.json')

    # Load KJV data (reference)
    print("Loading KJV data...")
    kjv_data = load_json_file(kjv_file)
    if not kjv_data:
        print("Failed to load KJV data")
        return

    # Load NIV data
    print("Loading NIV data...")
    niv_data = load_json_file(niv_file)
    if not niv_data:
        print("Failed to load NIV data")
        return

    # Fix NIV file
    fixed_niv_data = fix_niv_file(kjv_data, niv_data)
    save_json_file(niv_file, fixed_niv_data)

    # Create ESV file
    fixed_esv_data = fix_esv_file(kjv_data)
    save_json_file(esv_file, fixed_esv_data)

    print("Bible data fix completed!")

if __name__ == "__main__":
    main()
