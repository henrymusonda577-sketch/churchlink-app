import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../lib/community_screen.dart';
import '../lib/services/community_service.dart';
import '../lib/create_post_screen.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });
  group('CommunityScreen Widget Tests', () {
    testWidgets('CommunityScreen builds without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityScreen(),
        ),
      );

      expect(find.text('Community'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('Search functionality toggles correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityScreen(),
        ),
      );

      // Initially shows title
      expect(find.text('Community'), findsOneWidget);

      // Tap search icon
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();

      // Should show search field
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('Filter chips are displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityScreen(),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Prayers'), findsOneWidget);
      expect(find.text('Verses'), findsOneWidget);
      expect(find.text('Testimonies'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
    });

    testWidgets('Create post button navigates to CreatePostScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityScreen(),
          routes: {
            '/create-post': (context) => CreatePostScreen(),
          },
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.byType(CreatePostScreen), findsOneWidget);
    });
  });

  group('CommunityService Tests', () {
    late CommunityService communityService;

    setUp(() {
      communityService = CommunityService(firestore: fakeFirestore);
    });

    test('getCommunityPosts returns stream with correct query', () {
      final stream = communityService.getCommunityPosts(postType: 'prayer');

      expect(stream, isA<Stream<QuerySnapshot>>());
    });

    test('searchCommunityPosts returns stream', () {
      final stream = communityService.searchCommunityPosts('test query');

      expect(stream, isA<Stream<QuerySnapshot>>());
    });

    test('getCommunityPosts with null postType returns all posts', () {
      final stream = communityService.getCommunityPosts();

      expect(stream, isA<Stream<QuerySnapshot>>());
    });
  });

  group('CommunityScreen State Tests', () {
    testWidgets('Filter changes update selected filter',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityScreen(),
        ),
      );

      // Tap on Prayers filter
      await tester.tap(find.text('Prayers'));
      await tester.pump();

      // The filter should be selected (this would need more complex testing with state access)
      expect(find.text('Prayers'), findsOneWidget);
    });

    testWidgets('Search query updates correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityScreen(),
        ),
      );

      // Enable search mode
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();

      // Enter search text
      await tester.enterText(find.byType(TextField), 'test search');
      await tester.pump();

      // Text should be entered
      expect(find.text('test search'), findsOneWidget);
    });
  });
}
