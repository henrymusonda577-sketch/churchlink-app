import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'bible_verse_screen.dart';

class BibleChapterScreen extends StatefulWidget {
  final String bookName;
  final int chapters;
  final String testament;

  const BibleChapterScreen({
    super.key,
    required this.bookName,
    required this.chapters,
    required this.testament,
  });

  @override
  State<BibleChapterScreen> createState() => _BibleChapterScreenState();
}

class _BibleChapterScreenState extends State<BibleChapterScreen> {
  Map<String, dynamic>? _bibleData;
  bool _isLoading = true;
  String _selectedVersion = 'NIV';

  @override
  void initState() {
    super.initState();
    _loadBibleData();
  }

  Future<void> _loadBibleData() async {
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
      _isLoading = true;
      _bibleData = null;
    });
    _loadBibleData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookName),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
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
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E3A8A),
            child: Text(
              '${widget.chapters} Chapters • ${widget.testament} Testament',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: widget.chapters,
              itemBuilder: (context, index) {
                final chapterNumber = index + 1;
                return _buildChapterButton(chapterNumber);
              },
            ),
    );
  }

  Widget _buildChapterButton(int chapterNumber) {
    return ElevatedButton(
      onPressed: () => _navigateToVerses(chapterNumber),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      child: Text(
        chapterNumber.toString(),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _navigateToVerses(int chapterNumber) {
    if (_bibleData == null) return;

    final bookData = _bibleData!['books'][widget.bookName];
    if (bookData == null) return;

    final chapterData = bookData['chapters'][chapterNumber.toString()];
    if (chapterData == null) return;

    // Convert array of verses to map with verse numbers as keys
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
          bookName: widget.bookName,
          chapterNumber: chapterNumber,
          verses: versesMap,
          version: _selectedVersion,
        ),
      ),
    );
  }
}
