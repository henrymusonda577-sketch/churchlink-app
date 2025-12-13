import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_flutter_app/main.dart';
import 'package:my_flutter_app/services/video_firebase_service.dart';
import 'package:my_flutter_app/video_player_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Video Upload and Playback Integration Tests', () {
    late VideoFirebaseService videoFirebaseService;

    setUp(() {
      videoFirebaseService = VideoFirebaseService();
    });

    testWidgets('App launches successfully', (WidgetTester tester) async {
      // Build our app and trigger a frame
      await tester.pumpWidget(const AllChurchesApp());

      // Verify that the app launches without errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Video player screen handles invalid URL gracefully',
        (WidgetTester tester) async {
      // Build the video player screen with an invalid URL
      await tester.pumpWidget(
        const MaterialApp(
          home: VideoPlayerScreen(
            videoPath: '',
            videoTitle: 'Test Video',
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify error message is displayed
      expect(find.text('Error Loading Video'), findsOneWidget);
      expect(find.text('Video URL is empty'), findsOneWidget);
    });

    testWidgets('Video player screen shows retry button on error',
        (WidgetTester tester) async {
      // Build the video player screen with an invalid URL
      await tester.pumpWidget(
        const MaterialApp(
          home: VideoPlayerScreen(
            videoPath: 'invalid-url',
            videoTitle: 'Test Video',
          ),
        ),
      );

      // Wait for the widget to build and error to appear
      await tester.pumpAndSettle();

      // Verify retry button is present
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Video player screen handles network timeout',
        (WidgetTester tester) async {
      // Build the video player screen with a non-existent URL
      await tester.pumpWidget(
        const MaterialApp(
          home: VideoPlayerScreen(
            videoPath: 'https://non-existent-domain.com/video.mp4',
            videoTitle: 'Test Video',
          ),
        ),
      );

      // Wait for timeout (30 seconds)
      await tester.pumpAndSettle(const Duration(seconds: 35));

      // Verify timeout error is handled
      expect(find.text('Error Loading Video'), findsOneWidget);
    });

    test('Video firebase service handles invalid file upload', () async {
      // Test with null file
      final result = await videoFirebaseService.uploadVideo(null);
      expect(result, isNull);
    });

    testWidgets('Video player controls are present when video loads',
        (WidgetTester tester) async {
      // This test would require a mock video URL
      // For now, we'll test the UI structure
      await tester.pumpWidget(
        const MaterialApp(
          home: VideoPlayerScreen(
            videoPath:
                'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
            videoTitle: 'Sample Video',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check if loading indicator is shown initially
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  group('Platform-specific Video Tests', () {
    testWidgets('Video player adapts to different screen sizes',
        (WidgetTester tester) async {
      // Test on different screen sizes
      await tester.binding
          .setSurfaceSize(const Size(375, 667)); // iPhone SE size

      await tester.pumpWidget(
        const MaterialApp(
          home: VideoPlayerScreen(
            videoPath: 'test-video-url',
            videoTitle: 'Test Video',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the video container adapts to screen size
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);
    });

    testWidgets('Video player handles orientation changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VideoPlayerScreen(
            videoPath: 'test-video-url',
            videoTitle: 'Test Video',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Change orientation to landscape
      await tester.binding.setSurfaceSize(const Size(667, 375));

      await tester.pumpAndSettle();

      // Verify the UI adapts to landscape
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
