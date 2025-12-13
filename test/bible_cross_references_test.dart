import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:my_flutter_app/services/bible_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Cross References Toggle Tests', () {
    late BibleService bibleService;

    setUp(() {
      bibleService = BibleService();
    });

    test('Cross references are loaded for verses', () async {
      // Test that cross references can be loaded for a verse
      final crossRefs =
          await bibleService.getCrossReferencesForVerse('John', '1', 1);
      expect(crossRefs, isA<List<String>>());
      // Note: The actual content depends on the cross_references.json file
    });

    test('Cross references toggle logic', () {
      // Test the toggle logic - this simulates the UI toggle behavior
      bool showCrossReferences = false;

      // Initially hidden
      expect(showCrossReferences, false);

      // Toggle on
      showCrossReferences = !showCrossReferences;
      expect(showCrossReferences, true);

      // Toggle off
      showCrossReferences = !showCrossReferences;
      expect(showCrossReferences, false);
    });

    test('Cross references data structure', () async {
      // Test that the cross references are properly structured
      final crossRefs =
          await bibleService.getCrossReferencesForVerse('Genesis', '1', 1);
      expect(crossRefs, isA<List<String>>());

      if (crossRefs.isNotEmpty) {
        // If there are cross references, they should be strings
        for (final ref in crossRefs) {
          expect(ref, isA<String>());
          expect(ref.isNotEmpty, true);
        }
      }
    });
  });
}
