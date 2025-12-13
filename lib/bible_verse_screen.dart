import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class BibleVerseScreen extends StatefulWidget {
  final String bookName;
  final int chapterNumber;
  final Map<String, String> verses;
  final String version;

  const BibleVerseScreen({
    super.key,
    required this.bookName,
    required this.chapterNumber,
    required this.verses,
    required this.version,
  });

  @override
  State<BibleVerseScreen> createState() => _BibleVerseScreenState();
}

class _BibleVerseScreenState extends State<BibleVerseScreen> {
  double _fontSize = 16.0;
  bool _showVerseNumbers = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, String> _filteredVerses = {};
  Set<String> _bookmarkedVerses = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadBookmarks();
    _filteredVerses = Map.from(widget.verses);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${widget.bookName}_${widget.chapterNumber}_bookmarks';
    final bookmarked = prefs.getStringList(key) ?? [];
    setState(() {
      _bookmarkedVerses = bookmarked.toSet();
    });
  }

  void _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${widget.bookName}_${widget.chapterNumber}_bookmarks';
    await prefs.setStringList(key, _bookmarkedVerses.toList());
  }

  void _toggleBookmark(String verseNumber) {
    setState(() {
      if (_bookmarkedVerses.contains(verseNumber)) {
        _bookmarkedVerses.remove(verseNumber);
      } else {
        _bookmarkedVerses.add(verseNumber);
      }
    });
    _saveBookmarks();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredVerses = Map.from(widget.verses);
      } else {
        _filteredVerses = Map.fromEntries(
          widget.verses.entries.where(
            (entry) => entry.value.toLowerCase().contains(_searchQuery),
          ),
        );
      }
    });
  }

  void _scrollToVerse(String verseNumber) {
    // Find the index of the verse in the filtered list
    final verseIndex = _filteredVerses.keys.toList().indexOf(verseNumber);
    if (verseIndex == -1) return;
    final scrollPosition = verseIndex * 100.0; // Approximate position
    _scrollController.animateTo(
      scrollPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.bookName} ${widget.chapterNumber}'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'font_size',
                child: Text('Font Size'),
              ),
              PopupMenuItem(
                value: 'verse_numbers',
                child: Text(_showVerseNumbers
                    ? 'Hide Verse Numbers'
                    : 'Show Verse Numbers'),
              ),
              const PopupMenuItem(
                value: 'view_bookmarks',
                child: Text('View Bookmarks'),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Text('Share Chapter'),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E3A8A),
            child: Text(
              '${_filteredVerses.length} verses • ${widget.version}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Verse navigation bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Text(
                  'Jump to verse:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filteredVerses.length,
                      itemBuilder: (context, index) {
                        final verseNumber = _filteredVerses.keys.elementAt(index);
                        return Container(
                          width: 30,
                          margin: const EdgeInsets.only(right: 4),
                          child: TextButton(
                            onPressed: () => _scrollToVerse(verseNumber),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(30, 30),
                            ),
                            child: Text(
                              verseNumber,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Verses content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _filteredVerses.entries.map((entry) {
                  final verseNumber = entry.key;
                  final verseText = entry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showVerseDialog(verseNumber, verseText),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_showVerseNumbers)
                                Container(
                                  width: 30,
                                  alignment: Alignment.topRight,
                                  child: Text(
                                    '$verseNumber ',
                                    style: TextStyle(
                                      fontSize: _fontSize - 2,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E3A8A),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  verseText,
                                  style: TextStyle(
                                    fontSize: _fontSize,
                                    height: 1.5,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _bookmarkedVerses.contains(verseNumber)
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: const Color(0xFF1E3A8A),
                                ),
                                onPressed: () => _toggleBookmark(verseNumber),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Tap on any verse to view it in detail',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showVerseSelector,
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.list, color: Colors.white),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search in Chapter'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Enter search term...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchController.clear();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'font_size':
        _showFontSizeDialog();
        break;
      case 'verse_numbers':
        setState(() {
          _showVerseNumbers = !_showVerseNumbers;
        });
        break;
      case 'view_bookmarks':
        _showBookmarksDialog();
        break;
      case 'share':
        _shareChapter();
        break;
    }
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Font Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: _fontSize,
              min: 12,
              max: 24,
              divisions: 6,
              label: _fontSize.round().toString(),
              onChanged: (value) {
                setState(() {
                  _fontSize = value;
                });
              },
            ),
            Text('Font size: ${_fontSize.round()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showVerseSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 300,
        child: Column(
          children: [
            const Text(
              'Jump to Verse',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _filteredVerses.length,
                itemBuilder: (context, index) {
                  final verseNumber = _filteredVerses.keys.elementAt(index);
                  return ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _scrollToVerse(verseNumber);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      verseNumber,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookmarksDialog() {
    if (_bookmarkedVerses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bookmarked verses')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 300,
        child: Column(
          children: [
            const Text(
              'Bookmarked Verses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: _bookmarkedVerses.map((verseNumber) {
                  final verseText = _filteredVerses[verseNumber] ?? widget.verses[verseNumber] ?? '';
                  return ListTile(
                    title: Text('$verseNumber: $verseText'),
                    onTap: () {
                      Navigator.pop(context);
                      _scrollToVerse(verseNumber);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerseDialog(String verseNumber, String verseText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.bookName} ${widget.chapterNumber}:$verseNumber'),
        content: Text(verseText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _shareChapter() {
    final chapterText = _filteredVerses.entries
        .map((entry) =>
            '${widget.bookName} ${widget.chapterNumber}:${entry.key} ${entry.value}')
        .join('\n\n');

    Share.share(
      chapterText,
      subject: 'Bible Chapter: ${widget.bookName} ${widget.chapterNumber} (${widget.version})',
    );
  }
}
