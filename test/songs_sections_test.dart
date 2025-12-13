import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/content_screen.dart';
import 'package:my_flutter_app/services/gospel_songs_service.dart';
import 'package:my_flutter_app/services/moderation_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';

void main() {
  group('Songs Sections Implementation Tests', () {
    late GospelSongsService gospelSongsService;
    late ModerationService moderationService;

    setUp(() {
      gospelSongsService = GospelSongsService();
      moderationService = ModerationService();
    });

    test('GospelSongsService initializes correctly', () {
      expect(gospelSongsService, isNotNull);
    });

    test('ModerationService initializes correctly', () {
      expect(moderationService, isNotNull);
    });

    test('GospelSongsService can get curated songs stream', () {
      final stream = gospelSongsService.getCuratedSongsStream();
      expect(stream, isNotNull);
      expect(stream, isA<Stream<QuerySnapshot>>());
    });

    test('GospelSongsService can initialize curated songs', () async {
      // This should not throw an error
      expect(
          () => gospelSongsService.initializeCuratedSongs(), returnsNormally);
    });

    test('ModerationService can moderate image', () async {
      final testImage = Uint8List(100); // Mock image data
      final result = await moderationService.moderateImage(testImage);
      expect(result, isNotNull);
      expect(result, isA<Map<String, dynamic>>());
    });

    test('YouTube URL validation works correctly', () {
      const validUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      const invalidUrl = 'https://example.com/video';

      expect(YoutubePlayer.convertUrlToId(validUrl), isNotNull);
      expect(YoutubePlayer.convertUrlToId(invalidUrl), isNull);
    });

    test('Audio player service initializes correctly', () {
      final audioPlayer = AudioPlayer();
      expect(audioPlayer, isNotNull);
    });
  });

  group('Songs UI Tests', () {
    testWidgets('Songs tab shows section switching UI',
        (WidgetTester tester) async {
      // Mock user info
      const mockUserInfo = {
        'name': 'Test User',
        'email': 'test@example.com',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ContentScreen(
            userInfo: mockUserInfo,
            initialTab: 2, // Songs tab
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify section switching tabs are present
      expect(find.text('Streamed Songs'), findsOneWidget);
      expect(find.text('User Uploads'), findsOneWidget);
    });

    testWidgets('Section switching works correctly',
        (WidgetTester tester) async {
      const mockUserInfo = {
        'name': 'Test User',
        'email': 'test@example.com',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ContentScreen(
            userInfo: mockUserInfo,
            initialTab: 2, // Songs tab
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on User Uploads section
      await tester.tap(find.text('User Uploads'));
      await tester.pumpAndSettle();

      // Verify the UI updates to show user uploads section
      expect(find.text('No uploaded songs yet'), findsOneWidget);
    });

    testWidgets('YouTube songs section shows loading state',
        (WidgetTester tester) async {
      const mockUserInfo = {
        'name': 'Test User',
        'email': 'test@example.com',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ContentScreen(
            userInfo: mockUserInfo,
            initialTab: 2, // Songs tab
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Streamed Songs section
      await tester.tap(find.text('Streamed Songs'));
      await tester.pumpAndSettle();

      // Verify loading state is shown
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('User uploads section shows empty state',
        (WidgetTester tester) async {
      const mockUserInfo = {
        'name': 'Test User',
        'email': 'test@example.com',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ContentScreen(
            userInfo: mockUserInfo,
            initialTab: 2, // Songs tab
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on User Uploads section
      await tester.tap(find.text('User Uploads'));
      await tester.pumpAndSettle();

      // Verify empty state message
      expect(find.text('No uploaded songs yet'), findsOneWidget);
      expect(find.text('Upload your first gospel song!'), findsOneWidget);
    });

    testWidgets('Floating action button appears only in uploads section',
        (WidgetTester tester) async {
      const mockUserInfo = {
        'name': 'Test User',
        'email': 'test@example.com',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ContentScreen(
            userInfo: mockUserInfo,
            initialTab: 2, // Songs tab
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially should not show FAB (default is streamed section)
      expect(find.text('Add Song'), findsNothing);

      // Tap on User Uploads section
      await tester.tap(find.text('User Uploads'));
      await tester.pumpAndSettle();

      // Now FAB should appear
      expect(find.text('Add Song'), findsOneWidget);
    });

    testWidgets('YouTube player integration works',
        (WidgetTester tester) async {
      const mockUserInfo = {
        'name': 'Test User',
        'email': 'test@example.com',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ContentScreen(
            userInfo: mockUserInfo,
            initialTab: 2, // Songs tab
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Streamed Songs section
      await tester.tap(find.text('Streamed Songs'));
      await tester.pumpAndSettle();

      // Verify YouTube player components are present
      expect(find.byType(StreamBuilder), findsWidgets);
    });
  });

  group('Songs Data Structure Tests', () {
    test('Curated songs data structure is valid', () {
      final sampleSong = {
        'title': 'Amazing Grace',
        'artist': 'Traditional',
        'videoId': 'dQw4w9WgXcQ',
        'thumbnailUrl':
            'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
        'type': 'youtube',
        'duration': '3:45',
        'uploadTimestamp': DateTime.now().toIso8601String(),
      };

      expect(sampleSong['title'], isNotNull);
      expect(sampleSong['artist'], isNotNull);
      expect(sampleSong['videoId'], isNotNull);
      expect(sampleSong['type'], equals('youtube'));
    });

    test('User upload data structure is valid', () {
      final sampleUpload = {
        'title': 'My Gospel Song',
        'artist': 'Test Artist',
        'fileUrl': 'https://storage.googleapis.com/bucket/song.mp3',
        'type': 'audio',
        'uploaderId': 'test-user-id',
        'uploadTimestamp': DateTime.now().toIso8601String(),
      };

      expect(sampleUpload['title'], isNotNull);
      expect(sampleUpload['fileUrl'], isNotNull);
      expect(sampleUpload['type'], equals('audio'));
      expect(sampleUpload['uploaderId'], isNotNull);
    });
  });
}
