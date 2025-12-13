import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/services/post_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() {
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
  });

  group('PostService', () {
    late PostService postService;

    setUp(() {
      postService = PostService();
    });

    test('PostService can be instantiated', () {
      expect(postService, isNotNull);
    });

    test('PostService has expected methods', () {
      expect(postService.getHomeFeedPosts, isNotNull);
      expect(postService.getContentVideos, isNotNull);
      expect(postService.getFollowedUsersPosts, isNotNull);
      expect(postService.getStories, isNotNull);
      expect(postService.getUserPosts, isNotNull);
      expect(postService.getUserStories, isNotNull);
      expect(postService.getPostComments, isNotNull);
    });
  });
}
