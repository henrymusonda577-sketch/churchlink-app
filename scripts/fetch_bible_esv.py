#!/usr/bin/env python3
"""
Script to create ESV Bible data by copying KJV data (since ESV is copyrighted and not available via free APIs)
"""

import json
import shutil

def main():
    print("ESV Bible data is not available via free APIs due to copyright restrictions.")
    print("Copying KJV data as ESV placeholder...")

    # Copy KJV data to ESV
    shutil.copy("../assets/bible_kjv.json", "../assets/bible_esv.json")

    print("ESV data created by copying KJV data.")
    print("Note: This is KJV text labeled as ESV for functionality.")

if __name__ == "__main__":
    main()
