import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'bible_chapter_screen.dart';
import 'bible_verse_screen.dart';

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  final List<Map<String, dynamic>> _bibleBooks = [
    {'name': 'Genesis', 'chapters': 50, 'testament': 'Old'},
    {'name': 'Exodus', 'chapters': 40, 'testament': 'Old'},
    {'name': 'Leviticus', 'chapters': 27, 'testament': 'Old'},
    {'name': 'Numbers', 'chapters': 36, 'testament': 'Old'},
    {'name': 'Deuteronomy', 'chapters': 34, 'testament': 'Old'},
    {'name': 'Joshua', 'chapters': 24, 'testament': 'Old'},
    {'name': 'Judges', 'chapters': 21, 'testament': 'Old'},
    {'name': 'Ruth', 'chapters': 4, 'testament': 'Old'},
    {'name': '1 Samuel', 'chapters': 31, 'testament': 'Old'},
    {'name': '2 Samuel', 'chapters': 24, 'testament': 'Old'},
    {'name': '1 Kings', 'chapters': 22, 'testament': 'Old'},
    {'name': '2 Kings', 'chapters': 25, 'testament': 'Old'},
    {'name': '1 Chronicles', 'chapters': 29, 'testament': 'Old'},
    {'name': '2 Chronicles', 'chapters': 36, 'testament': 'Old'},
    {'name': 'Ezra', 'chapters': 10, 'testament': 'Old'},
    {'name': 'Nehemiah', 'chapters': 13, 'testament': 'Old'},
    {'name': 'Esther', 'chapters': 10, 'testament': 'Old'},
    {'name': 'Job', 'chapters': 42, 'testament': 'Old'},
    {'name': 'Psalms', 'chapters': 150, 'testament': 'Old'},
    {'name': 'Proverbs', 'chapters': 31, 'testament': 'Old'},
    {'name': 'Ecclesiastes', 'chapters': 12, 'testament': 'Old'},
    {'name': 'Song of Solomon', 'chapters': 8, 'testament': 'Old'},
    {'name': 'Isaiah', 'chapters': 66, 'testament': 'Old'},
    {'name': 'Jeremiah', 'chapters': 52, 'testament': 'Old'},
    {'name': 'Lamentations', 'chapters': 5, 'testament': 'Old'},
    {'name': 'Ezekiel', 'chapters': 48, 'testament': 'Old'},
    {'name': 'Daniel', 'chapters': 12, 'testament': 'Old'},
    {'name': 'Hosea', 'chapters': 14, 'testament': 'Old'},
    {'name': 'Joel', 'chapters': 3, 'testament': 'Old'},
    {'name': 'Amos', 'chapters': 9, 'testament': 'Old'},
    {'name': 'Obadiah', 'chapters': 1, 'testament': 'Old'},
    {'name': 'Jonah', 'chapters': 4, 'testament': 'Old'},
    {'name': 'Micah', 'chapters': 7, 'testament': 'Old'},
    {'name': 'Nahum', 'chapters': 3, 'testament': 'Old'},
    {'name': 'Habakkuk', 'chapters': 3, 'testament': 'Old'},
    {'name': 'Zephaniah', 'chapters': 3, 'testament': 'Old'},
    {'name': 'Haggai', 'chapters': 2, 'testament': 'Old'},
    {'name': 'Zechariah', 'chapters': 14, 'testament': 'Old'},
    {'name': 'Malachi', 'chapters': 4, 'testament': 'Old'},
    {'name': 'Matthew', 'chapters': 28, 'testament': 'New'},
    {'name': 'Mark', 'chapters': 16, 'testament': 'New'},
    {'name': 'Luke', 'chapters': 24, 'testament': 'New'},
    {'name': 'John', 'chapters': 21, 'testament': 'New'},
    {'name': 'Acts', 'chapters': 28, 'testament': 'New'},
    {'name': 'Romans', 'chapters': 16, 'testament': 'New'},
    {'name': '1 Corinthians', 'chapters': 16, 'testament': 'New'},
    {'name': '2 Corinthians', 'chapters': 13, 'testament': 'New'},
    {'name': 'Galatians', 'chapters': 6, 'testament': 'New'},
    {'name': 'Ephesians', 'chapters': 6, 'testament': 'New'},
    {'name': 'Philippians', 'chapters': 4, 'testament': 'New'},
    {'name': 'Colossians', 'chapters': 4, 'testament': 'New'},
    {'name': '1 Thessalonians', 'chapters': 5, 'testament': 'New'},
    {'name': '2 Thessalonians', 'chapters': 3, 'testament': 'New'},
    {'name': '1 Timothy', 'chapters': 6, 'testament': 'New'},
    {'name': '2 Timothy', 'chapters': 4, 'testament': 'New'},
    {'name': 'Titus', 'chapters': 3, 'testament': 'New'},
    {'name': 'Philemon', 'chapters': 1, 'testament': 'New'},
    {'name': 'Hebrews', 'chapters': 13, 'testament': 'New'},
    {'name': 'James', 'chapters': 5, 'testament': 'New'},
    {'name': '1 Peter', 'chapters': 5, 'testament': 'New'},
    {'name': '2 Peter', 'chapters': 3, 'testament': 'New'},
    {'name': '1 John', 'chapters': 5, 'testament': 'New'},
    {'name': '2 John', 'chapters': 1, 'testament': 'New'},
    {'name': '3 John', 'chapters': 1, 'testament': 'New'},
    {'name': 'Jude', 'chapters': 1, 'testament': 'New'},
    {'name': 'Revelation', 'chapters': 22, 'testament': 'New'},
  ];

  String _selectedTestament = 'All';
  String _searchQuery = '';
  Map<String, dynamic>? _bibleData;
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  String _selectedVersion = 'NIV';

  @override
  void initState() {
    super.initState();
    _loadBibleData();
  }

  Future<void> _loadBibleData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final String jsonString = await rootBundle.loadString(
        _selectedVersion == 'NIV'
            ? 'assets/bible_niv.json'
            : _selectedVersion == 'ESV'
                ? 'assets/bible_esv.json'
                : 'assets/bible_kjv.json',
      );
      final data = json.decode(jsonString);
      setState(() {
        _bibleData = data;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bible data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _changeVersion(String version) {
    setState(() {
      _selectedVersion = version;
      _bibleData = null;
      _searchResults = [];
    });
    _loadBibleData();
  }

  void _performSearch(String query) {
    if (_bibleData == null || query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final results = <Map<String, dynamic>>[];
    final books = _bibleData!['books'] as Map<String, dynamic>;

    books.forEach((bookName, bookData) {
      final chapters = bookData['chapters'] as Map<String, dynamic>;
      chapters.forEach((chapterNum, chapterData) {
        if (chapterData is List) {
          for (int verseIndex = 0; verseIndex < chapterData.length; verseIndex++) {
            final verseText = chapterData[verseIndex] as String;
            if (verseText.toLowerCase().contains(query.toLowerCase())) {
              results.add({
                'book': bookName,
                'chapter': chapterNum,
                'verse': (verseIndex + 1).toString(),
                'text': verseText,
              });
            }
          }
        } else if (chapterData is Map) {
          chapterData.forEach((verseNum, verseText) {
            if ((verseText as String).toLowerCase().contains(query.toLowerCase())) {
              results.add({
                'book': bookName,
                'chapter': chapterNum,
                'verse': verseNum,
                'text': verseText,
              });
            }
          });
        }
      });
    });

    setState(() {
      _searchResults = results;
    });
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              '${result['book']} ${result['chapter']}:${result['verse']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            subtitle: Text(
              result['text'],
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _navigateToVerse(result),
          ),
        );
      },
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No verses found for "${_searchQuery}"',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookList(List<Map<String, dynamic>> books) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return _buildBookCard(book);
      },
    );
  }

  void _navigateToVerse(Map<String, dynamic> result) {
    final bookName = result['book'];
    final chapterNum = int.parse(result['chapter']);

    // First navigate to the chapter
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BibleChapterScreen(
          bookName: bookName,
          chapters: _bibleBooks.firstWhere((b) => b['name'] == bookName)['chapters'],
          testament: _bibleBooks.firstWhere((b) => b['name'] == bookName)['testament'],
        ),
      ),
    ).then((_) {
      // After returning from chapter screen, navigate to verse screen
      final bookData = _bibleData!['books'][bookName];
      final chapterData = bookData['chapters'][chapterNum.toString()];
      final Map<String, String> versesMap = {};

      if (chapterData is List) {
        for (int i = 0; i < chapterData.length; i++) {
          versesMap[(i + 1).toString()] = chapterData[i];
        }
      } else if (chapterData is Map) {
        versesMap.addAll(Map<String, String>.from(chapterData));
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BibleVerseScreen(
            bookName: bookName,
            chapterNumber: chapterNum,
            verses: versesMap,
            version: _selectedVersion,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredBooks = _bibleBooks.where((book) {
      final matchesTestament = _selectedTestament == 'All' ||
          book['testament'] == _selectedTestament;
      final matchesSearch = _searchQuery.isEmpty ||
          book['name'].toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesTestament && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        title: const Text(
          'Holy Bible',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _changeVersion,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'NIV', child: Text('NIV')),
              const PopupMenuItem(value: 'ESV', child: Text('ESV')),
              const PopupMenuItem(value: 'KJV', child: Text('KJV')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _selectedVersion,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: _searchQuery.isEmpty ? 'Search books or verses...' : 'Searching verses...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _performSearch(value);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTestamentChip('All'),
                  _buildTestamentChip('Old'),
                  _buildTestamentChip('New'),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildVerseOfDay(),
                Expanded(
                  child: _searchQuery.isNotEmpty && _searchResults.isNotEmpty
                      ? _buildSearchResults()
                      : _searchQuery.isNotEmpty && _searchResults.isEmpty
                          ? _buildNoResults()
                          : _buildBookList(filteredBooks),
                ),
              ],
            ),
    );
  }

  Widget _buildTestamentChip(String testament) {
    final isSelected = _selectedTestament == testament;
    return GestureDetector(
      onTap: () => setState(() => _selectedTestament = testament),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white),
        ),
        child: Text(
          testament,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildVerseOfDay() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Verse of the Day',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '"Trust in the LORD with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight."',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Proverbs 3:5-6',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: book['testament'] == 'Old'
              ? Colors.orange.withOpacity(0.2)
              : Colors.blue.withOpacity(0.2),
          child: Icon(
            Icons.book,
            color: book['testament'] == 'Old' ? Colors.orange : Colors.blue,
          ),
        ),
        title: Text(
          book['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
            '${book['chapters']} chapters • ${book['testament']} Testament'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BibleChapterScreen(
                bookName: book['name'],
                chapters: book['chapters'],
                testament: book['testament'],
              ),
            ),
          );
        },
      ),
    );
  }
}
