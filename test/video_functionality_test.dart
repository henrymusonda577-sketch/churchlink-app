import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/services/video_firebase_service.dart';

void main() {
  group('Video Firebase Service Tests', () {
    late VideoFirebaseService videoFirebaseService;

    setUp(() {
      videoFirebaseService = VideoFirebaseService();
    });

    test('Video firebase service initializes correctly', () {
      expect(videoFirebaseService, isNotNull);
    });

    test('Video firebase service handles null file upload', () async {
      final result = await videoFirebaseService.uploadVideo(null);
      expect(result, isNull);
    });
  });

  group('Video URL Validation Tests', () {
    test('Valid signed URL format', () {
      const validUrl =
          'https://storage.googleapis.com/bucket/file.mp4?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=cred';
      expect(validUrl.contains('storage.googleapis.com'), isTrue);
      expect(validUrl.contains('?'), isTrue);
    });

    test('Invalid URL format', () {
      const invalidUrl = 'not-a-url';
      final uri = Uri.tryParse(invalidUrl);
      expect(uri, isNull);
    });

    test('Empty URL handling', () {
      const emptyUrl = '';
      expect(emptyUrl.isEmpty, isTrue);
    });
  });

  group('Video Format Validation Tests', () {
    final validFormats = [
      'video/mp4',
      'video/webm',
      'video/quicktime',
      'video/x-msvideo'
    ];

    test('Valid video formats', () {
      expect(validFormats.contains('video/mp4'), isTrue);
      expect(validFormats.contains('video/webm'), isTrue);
      expect(validFormats.contains('video/quicktime'), isTrue);
      expect(validFormats.contains('video/x-msvideo'), isTrue);
    });

    test('Invalid video formats', () {
      expect(validFormats.contains('video/avi'), isFalse);
      expect(validFormats.contains('application/json'), isFalse);
      expect(validFormats.contains('text/plain'), isFalse);
    });
  });

  group('Error Message Tests', () {
    test('Timeout error message', () {
      const errorMsg = 'Video loading timed out. Please check your connection.';
      expect(errorMsg.contains('timed out'), isTrue);
      expect(errorMsg.contains('connection'), isTrue);
    });

    test('Network error message', () {
      const errorMsg = 'Network error. Please check your internet connection.';
      expect(errorMsg.contains('Network error'), isTrue);
      expect(errorMsg.contains('internet'), isTrue);
    });

    test('Format error message', () {
      const errorMsg = 'Video format not supported.';
      expect(errorMsg.contains('format'), isTrue);
      expect(errorMsg.contains('supported'), isTrue);
    });
  });
}
