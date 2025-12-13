# PowerShell script to fetch full Bible data for KJV and ESV from Project Gutenberg and update JSON files
# This script downloads the plain text, parses it, and writes the JSON files
# NIV is not public domain, so skipped

$translations = @{
    "KJV" = "https://www.gutenberg.org/files/10/10-0.txt"
    # ESV is not available on Project Gutenberg as it's copyrighted
    # "ESV" = "https://www.gutenberg.org/files/2016/2016.txt"
}

$books = @(
    "Genesis","Exodus","Leviticus","Numbers","Deuteronomy","Joshua","Judges","Ruth",
    "1 Samuel","2 Samuel","1 Kings","2 Kings","1 Chronicles","2 Chronicles","Ezra","Nehemiah",
    "Esther","Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon","Isaiah","Jeremiah",
    "Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos","Obadiah","Jonah","Micah",
    "Nahum","Habakkuk","Zephaniah","Haggai","Zechariah","Malachi","Matthew","Mark",
    "Luke","John","Acts","Romans","1 Corinthians","2 Corinthians","Galatians","Ephesians",
    "Philippians","Colossians","1 Thessalonians","2 Thessalonians","1 Timothy","2 Timothy",
    "Titus","Philemon","Hebrews","James","1 Peter","2 Peter","1 John","2 John","3 John",
    "Jude","Revelation"
)

foreach ($translationKey in $translations.Keys) {
    $url = $translations[$translationKey]
    Write-Host "Downloading $translationKey text..."
    Invoke-WebRequest -Uri $url -OutFile "$translationKey.txt" -ErrorAction Stop

    $lines = Get-Content "$translationKey.txt"
    $bibleData = @{
        "books" = @{}
    }
    $currentBook = $null
    $currentChapter = $null
    $currentVerses = @()

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($books -contains $trimmed) {
            if ($currentBook -and $currentChapter) {
                $bibleData["books"][$currentBook]["chapters"][$currentChapter] = $currentVerses
            }
            $currentBook = $trimmed
            $bibleData["books"][$currentBook] = @{
                "testament" = if ($books.IndexOf($currentBook) -lt 39) { "Old Testament" } else { "New Testament" }
                "chapters" = @{}
            }
            $currentChapter = $null
            $currentVerses = @()
        } elseif ($trimmed -match '^(\d+):(\d+)\s+(.+)$') {
            $chapter = $matches[1]
            $verse = $matches[2]
            $text = $matches[3]
            if ($chapter -ne $currentChapter) {
                if ($currentChapter) {
                    $bibleData["books"][$currentBook]["chapters"][$currentChapter] = $currentVerses
                }
                $currentChapter = $chapter
                $currentVerses = @()
            }
            $currentVerses += $text
        }
    }
    if ($currentBook -and $currentChapter) {
        $bibleData["books"][$currentBook]["chapters"][$currentChapter] = $currentVerses
    }

    $jsonOutput = $bibleData | ConvertTo-Json -Depth 10
    $outputPath = "../assets/bible_$($translationKey.ToLower()).json"
    Write-Host "Writing data to $outputPath"
    $jsonOutput | Out-File -FilePath $outputPath -Encoding UTF8

    # Remove-Item "$translationKey.txt"
}

Write-Host "Bible data fetching and update complete."
