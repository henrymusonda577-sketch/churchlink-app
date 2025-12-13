#!/usr/bin/env node

/**
 * Script to fix Bible verse data by replacing placeholder text with actual KJV verses
 */

const fs = require('fs');
const path = require('path');

function parseKJVText(text) {
    const lines = text.split('\n');
    const bibleData = {};

    let currentBook = null;
    let currentChapter = null;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line) continue;

        // Skip header lines
        if (line.startsWith('***') || line.includes('GUTENBERG') || line.includes('PROJECT')) continue;

        // Check for book start
        const bookNames = [
            "Genesis","Exodus","Leviticus","Numbers","Deuteronomy","Joshua","Judges","Ruth",
            "1 Samuel","2 Samuel","1 Kings","2 Kings","1 Chronicles","2 Chronicles","Ezra","Nehemiah",
            "Esther","Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon","Isaiah","Jeremiah",
            "Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos","Obadiah","Jonah","Micah",
            "Nahum","Habakkuk","Zephaniah","Haggai","Zechariah","Malachi","Matthew","Mark",
            "Luke","John","Acts","Romans","1 Corinthians","2 Corinthians","Galatians","Ephesians",
            "Philippians","Colossians","1 Thessalonians","2 Thessalonians","1 Timothy","2 Timothy",
            "Titus","Philemon","Hebrews","James","1 Peter","2 Peter","1 John","2 John","3 John",
            "Jude","Revelation"
        ];

        let bookFound = null;
        for (const book of bookNames) {
            if (line.toLowerCase().includes(book.toLowerCase()) &&
                (line.toLowerCase().includes('book of') ||
                 line.toLowerCase().includes('gospel') ||
                 line.toLowerCase().trim() === book.toLowerCase())) {
                bookFound = book;
                break;
            }
        }

        if (bookFound) {
            currentBook = bookFound;
            bibleData[currentBook] = {};
            console.log(`Processing book: ${currentBook}`);
            continue;
        }

        // Check for verses
        if (currentBook && /^\d+:\d+/.test(line)) {
            const match = line.match(/(\d+):(\d+)\s+(.+)/);
            if (match) {
                const chapterNum = parseInt(match[1]);
                const verseNum = parseInt(match[2]);
                let verseText = match[3].trim();

                if (!bibleData[currentBook][chapterNum]) {
                    bibleData[currentBook][chapterNum] = {};
                }

                // Handle multi-line verses
                let j = i + 1;
                while (j < lines.length && lines[j].trim() && !/^\d+:\d+/.test(lines[j].trim())) {
                    verseText += " " + lines[j].trim();
                    j++;
                }
                i = j - 1; // Skip the lines we processed

                bibleData[currentBook][chapterNum][verseNum] = verseText;
            }
        }
    }

    return bibleData;
}

function isPlaceholderVerse(verseText) {
    return verseText.toLowerCase().includes("verse is being loaded") ||
           verseText.toLowerCase().includes("please check back later");
}

function updateBibleJson(kjvData, jsonFilePath) {
    console.log(`Updating ${jsonFilePath}...`);

    // Load existing JSON
    const bibleJson = JSON.parse(fs.readFileSync(jsonFilePath, 'utf8'));

    let updatedCount = 0;

    // Update each book
    for (const [bookName, bookData] of Object.entries(bibleJson.books)) {
        if (kjvData[bookName]) {
            const kjvBook = kjvData[bookName];

            for (const [chapterKey, versesArray] of Object.entries(bookData.chapters)) {
                const chapterNum = parseInt(chapterKey);

                if (kjvBook[chapterNum]) {
                    const kjvChapter = kjvBook[chapterNum];

                    // Update each verse in the array
                    for (let verseIndex = 0; verseIndex < versesArray.length; verseIndex++) {
                        const verseNum = verseIndex + 1; // Verses are 1-indexed

                        if (kjvChapter[verseNum]) {
                            const currentText = versesArray[verseIndex];

                            // Only update if it's a placeholder
                            if (isPlaceholderVerse(currentText)) {
                                const newText = kjvChapter[verseNum];
                                versesArray[verseIndex] = newText;
                                updatedCount++;
                                console.log(`  Updated ${bookName} ${chapterNum}:${verseNum}`);
                            }
                        }
                    }
                }
            }
        }
    }

    // Save updated JSON
    fs.writeFileSync(jsonFilePath, JSON.stringify(bibleJson, null, 2), 'utf8');

    console.log(`Updated ${updatedCount} verses in ${jsonFilePath}`);
    return updatedCount;
}

function main() {
    const scriptDir = path.dirname(__filename);
    const kjvPath = path.join(scriptDir, 'KJV.txt');
    const assetsDir = path.join(scriptDir, '..', 'assets');

    // Check if KJV file exists
    if (!fs.existsSync(kjvPath)) {
        console.error(`Error: KJV.txt not found at ${kjvPath}`);
        return;
    }

    console.log("Parsing KJV text file...");
    const kjvText = fs.readFileSync(kjvPath, 'utf8');
    const kjvData = parseKJVText(kjvText);
    console.log(`Parsed ${Object.keys(kjvData).length} books from KJV text`);

    // Update each Bible translation
    const translations = [
        ['bible_kjv.json', 'KJV'],
        ['bible_niv.json', 'NIV'],
        ['bible_esv.json', 'ESV']
    ];

    let totalUpdated = 0;
    for (const [filename, translation] of translations) {
        const jsonPath = path.join(assetsDir, filename);
        if (fs.existsSync(jsonPath)) {
            const updated = updateBibleJson(kjvData, jsonPath);
            totalUpdated += updated;
        } else {
            console.log(`Warning: ${jsonPath} not found`);
        }
    }

    console.log(`\nCompleted! Updated ${totalUpdated} verses total.`);
}

if (require.main === module) {
    main();
}