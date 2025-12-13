import 'package:flutter/material.dart';
import 'services/bible_service.dart';

class BookmarksScreen extends StatefulWidget {
  final BibleService bibleService;

  const BookmarksScreen({super.key, required this.bibleService});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<Map<String, dynamic>> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await widget.bibleService.getBookmarks();
    setState(() {
      _bookmarks = bookmarks;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: _bookmarks.isEmpty
          ? const Center(
              child: Text('No bookmarks yet'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _bookmarks.length,
              itemBuilder: (context, index) {
                final bookmark = _bookmarks[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${bookmark['book']} ${bookmark['chapter']}:${bookmark['verse']}'),
                    subtitle: Text(
                      bookmark['text'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteBookmark(bookmark),
                    ),
                    onTap: () => _navigateToVerse(bookmark),
                  ),
                );
              },
            ),
    );
  }

  void _deleteBookmark(Map<String, dynamic> bookmark) async {
    await widget.bibleService.removeBookmark(bookmark['book'], bookmark['chapter'], bookmark['verse']);
    _loadBookmarks();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bookmark removed')),
    );
  }

  void _navigateToVerse(Map<String, dynamic> bookmark) {
    Navigator.of(context).pop({
      'book': bookmark['book'],
      'chapter': bookmark['chapter'],
      'verse': bookmark['verse'],
    });
  }
}
