import 'package:flutter/material.dart';
import 'services/bible_service.dart';

class BibleVerseSelectorScreen extends StatefulWidget {
  const BibleVerseSelectorScreen({super.key});

  @override
  State<BibleVerseSelectorScreen> createState() =>
      _BibleVerseSelectorScreenState();
}

class _BibleVerseSelectorScreenState extends State<BibleVerseSelectorScreen> {
  final BibleService _bibleService = BibleService();

  String? selectedBook;
  int? selectedChapter;
  int? selectedVerse;
  String? selectedVerseText;

  List<Map<String, dynamic>> _oldTestamentBooks = [];
  List<Map<String, dynamic>> _newTestamentBooks = [];
  List<Map<String, dynamic>> _chapters = [];
  List<Map<String, dynamic>> _verses = [];
  bool _isLoading = true;
  String? _loadingError;
  String _currentTranslation = 'KJV';

  @override
  void initState() {
    super.initState();
    _loadBibleData();
  }

  Future<void> _loadBibleData() async {
    setState(() {
      _isLoading = true;
      _loadingError = null;
    });

    try {
      final books = await _bibleService.getBooks();
      _oldTestamentBooks =
          books.where((book) => book['testament'] == 'Old').toList();
      _newTestamentBooks =
          books.where((book) => book['testament'] == 'New').toList();

      setState(() {
        _isLoading = false;
        _loadingError = null;
      });
    } catch (e) {
      print('Error loading Bible data: $e');
      setState(() {
        _isLoading = false;
        _loadingError = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading Bible data: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadBibleData,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Bible Verse'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadingError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_loadingError'),
                      ElevatedButton(
                        onPressed: _loadBibleData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select a Book:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: [
                            if (_oldTestamentBooks.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'Old Testament',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              ..._oldTestamentBooks.map((book) => ListTile(
                                    title: Text(book['name']),
                                    onTap: () {
                                      setState(() {
                                        selectedBook = book['name'];
                                      });
                                      // TODO: Navigate to chapter selection
                                    },
                                  )),
                            ],
                            if (_newTestamentBooks.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'New Testament',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              ..._newTestamentBooks.map((book) => ListTile(
                                    title: Text(book['name']),
                                    onTap: () {
                                      setState(() {
                                        selectedBook = book['name'];
                                      });
                                      // TODO: Navigate to chapter selection
                                    },
                                  )),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
