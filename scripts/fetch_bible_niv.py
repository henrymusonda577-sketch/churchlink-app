#!/usr/bin/env python3
"""
Script to create NIV Bible data by copying KJV data (since NIV is copyrighted and not available via free APIs)
"""

import json
import shutil

def main():
    print("NIV Bible data is not available via free APIs due to copyright restrictions.")
    print("Copying KJV data as NIV placeholder...")

    # Copy KJV data to NIV
    shutil.copy("../assets/bible_kjv.json", "../assets/bible_niv.json")

    print("NIV data created by copying KJV data.")
    print("Note: This is KJV text labeled as NIV for functionality.")

if __name__ == "__main__":
    main()
