import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BibleService {
  static final BibleService _instance = BibleService._internal();
  factory BibleService() => _instance;
  BibleService._internal();

  Map<String, dynamic>? _bibleData;
  List<Map<String, dynamic>> _bookmarks = [];
  List<Map<String, dynamic>> _notes = [];

  Future<void> _loadBibleData() async {
    if (_bibleData != null) return;

    try {
      final String data = await rootBundle.loadString('assets/bible_kjv.json');
      _bibleData = json.decode(data);
    } catch (e) {
      _bibleData = {'books': []};
    }
  }

  Future<List<Map<String, dynamic>>> getBooks() async {
    await _loadBibleData();
    final books = _bibleData?['books'] as List? ?? [];
    return books.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getChapters(String bookName) async {
    await _loadBibleData();
    final books = _bibleData?['books'] as List? ?? [];

    for (final book in books) {
      if (book['name'] == bookName) {
        final chapters = book['chapters'] as List? ?? [];
        return chapters.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getVerses(
      String bookName, int chapter) async {
    await _loadBibleData();
    final books = _bibleData?['books'] as List? ?? [];

    for (final book in books) {
      if (book['name'] == bookName) {
        final chapters = book['chapters'] as List? ?? [];
        if (chapter <= chapters.length) {
          final verses = chapters[chapter - 1]['verses'] as List? ?? [];
          return verses.cast<Map<String, dynamic>>();
        }
      }
    }
    return [];
  }

  Future<void> addBookmark(
      String book, int chapter, int verse, String text) async {
    final bookmark = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _bookmarks.add(bookmark);
    await _saveBookmarks();
  }

  Future<void> removeBookmark(String book, int chapter, int verse) async {
    _bookmarks.removeWhere((bookmark) =>
        bookmark['book'] == book &&
        bookmark['chapter'] == chapter &&
        bookmark['verse'] == verse);
    await _saveBookmarks();
  }

  Future<List<Map<String, dynamic>>> getBookmarks() async {
    await _loadBookmarks();
    return _bookmarks;
  }

  Future<void> addNote(String book, int chapter, int verse, String note) async {
    final noteData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'note': note,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _notes.add(noteData);
    await _saveNotes();
  }

  Future<void> removeNote(String book, int chapter, int verse) async {
    _notes.removeWhere((note) =>
        note['book'] == book &&
        note['chapter'] == chapter &&
        note['verse'] == verse);
    await _saveNotes();
  }

  Future<void> updateNote(String id, String newNote) async {
    final index = _notes.indexWhere((note) => note['id'] == id);
    if (index != -1) {
      _notes[index]['note'] = newNote;
      await _saveNotes();
    }
  }

  Future<List<Map<String, dynamic>>> getNotes() async {
    await _loadNotes();
    return _notes;
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksJson = _bookmarks.map((b) => json.encode(b)).toList();
    await prefs.setStringList('bible_bookmarks', bookmarksJson);
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksJson = prefs.getStringList('bible_bookmarks') ?? [];
    _bookmarks = bookmarksJson
        .map((b) => json.decode(b) as Map<String, dynamic>)
        .toList();
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = _notes.map((n) => json.encode(n)).toList();
    await prefs.setStringList('bible_notes', notesJson);
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getStringList('bible_notes') ?? [];
    _notes =
        notesJson.map((n) => json.decode(n) as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> getVerseOfTheDay() async {
    return {
      'book': 'John',
      'chapter': 3,
      'verse': 16,
      'text':
          'For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.',
    };
  }

  Future<List<String>> getCrossReferencesForVerse(
      String book, String chapter, int verse) async {
    try {
      final String data =
          await rootBundle.loadString('assets/cross_references.json');
      final Map<String, dynamic> crossRefs = json.decode(data);

      final key = '$book $chapter:$verse';
      final refs = crossRefs[key] as List<dynamic>? ?? [];
      return refs.cast<String>();
    } catch (e) {
      print('Error loading cross references: $e');
      return [];
    }
  }
}
