import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'notification_service.dart';

class CommunityService {
  final SupabaseClient _supabase;

  CommunityService({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  // Create a new community post
  Future<void> createCommunityPost({
    required String content,
    required String postType,
    String? imageUrl,
    String? videoUrl,
    String? verseReference,
    String? tags,
    String? source,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        print('DEBUG: Error: No authenticated user');
        return;
      }

      print('DEBUG: ALERT - Creating community post: $postType, content: ${content.length > 50 ? content.substring(0, 50) : content}...');
      print('DEBUG: Content length: ${content.length}');
      print('DEBUG: Image URL: $imageUrl');
      print('DEBUG: Video URL: $videoUrl');
      print('DEBUG: Current user ID: ${currentUser.id}');
      print('DEBUG: Current user email: ${currentUser.email}');

      // Handle story posts differently - they go to stories table
      if (postType == 'story') {
        print('DEBUG: Creating story in Supabase stories table');
        final storyData = {
          'user_id': currentUser.id,
          'content': content,
          'image_url': imageUrl,
          'video_url': videoUrl,
          'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        };

        final response = await _supabase.from('stories').insert(storyData).select();
        print('DEBUG: Story created successfully: ${response}');
      } else {
        // Regular posts go to posts table
        final postData = {
          'user_id': currentUser.id,
          'content': content,
          'post_type': postType, // 'prayer', 'verse', 'reflection', 'announcement'
          'image_url': imageUrl,
          'video_url': videoUrl,
          'verse_reference': verseReference,
          'tags': tags,
          'source': source ?? 'home', // Track where the post was created
          'likes': [],
          'comments': [],
          'shares': 0,
        };

        print('DEBUG: Post data: $postData');

        final response = await _supabase.from('posts').insert(postData).select();
        print('DEBUG: Post created successfully: ${response}');
      }
    } catch (e) {
      print('DEBUG: Error creating community post: $e');
      print('DEBUG: Stack trace: ${e.toString()}');
      rethrow; // Re-throw to let the UI handle the error
    }
  }

  // Get community posts with pagination
  Stream<List<Map<String, dynamic>>> getCommunityPosts({String? postType}) {
    try {
      if (postType != null && postType != 'all') {
        return _supabase
            .from('posts')
            .stream(primaryKey: ['id'])
            .eq('post_type', postType)
            .order('created_at', ascending: false)
            .limit(20)
            .map((data) {
              final posts = List<Map<String, dynamic>>.from(data);
              print('DEBUG CommunityService.getCommunityPosts: Fetched ${posts.length} posts with postType: $postType');
              for (var post in posts) {
                print('DEBUG CommunityService.getCommunityPosts: Post ID: ${post['id']}, type: ${post['post_type']}, user_id: ${post['user_id']}');
              }
              return posts;
            });
      } else {
        return _supabase
            .from('posts')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .limit(20)
            .map((data) {
              final posts = List<Map<String, dynamic>>.from(data);
              print('DEBUG CommunityService.getCommunityPosts: Fetched ${posts.length} posts (all types)');
              for (var post in posts) {
                print('DEBUG CommunityService.getCommunityPosts: Post ID: ${post['id']}, type: ${post['post_type']}, user_id: ${post['user_id']}');
              }
              return posts;
            });
      }
    } catch (e) {
      print('Error fetching community posts: $e');
      return Stream.value([]);
    }
  }

  // Get text posts only (excluding videos) for home feed
  Stream<List<Map<String, dynamic>>> getTextPosts() {
    try {
      return _supabase
          .from('posts')
          .stream(primaryKey: ['id'])
          .neq('post_type', 'video')
          .order('created_at', ascending: false)
          .limit(20)
          .map((data) {
            final posts = List<Map<String, dynamic>>.from(data);
            print('DEBUG CommunityService.getTextPosts: Fetched ${posts.length} text posts');
            for (var post in posts) {
              print('DEBUG CommunityService.getTextPosts: Post ID: ${post['id']}, type: ${post['post_type']}, user_id: ${post['user_id']}');
            }
            return posts;
          });
    } catch (e) {
      print('Error fetching text posts: $e');
      return Stream.value([]);
    }
  }

  // Get posts by source (e.g., 'home' or 'tiktok')
  Stream<List<Map<String, dynamic>>> getPostsBySource(String source) {
    try {
      return _supabase
          .from('posts')
          .stream(primaryKey: ['id'])
          .eq('source', source)
          .order('created_at', ascending: false)
          .limit(20)
          .map((data) {
            final posts = List<Map<String, dynamic>>.from(data);
            print('DEBUG CommunityService.getPostsBySource: Fetched ${posts.length} posts from source: $source');
            for (var post in posts) {
              print('DEBUG CommunityService.getPostsBySource: Post ID: ${post['id']}, type: ${post['post_type']}, source: ${post['source']}, user_id: ${post['user_id']}');
            }
            return posts;
          });
    } catch (e) {
      print('Error fetching posts by source: $e');
      return Stream.value([]);
    }
  }

  // Like/unlike a post
  Future<void> toggleLike(String postId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    // Get current post with owner info
    final post = await _supabase.from('posts').select('likes, user_id').eq('id', postId).single();
    final likes = List<String>.from(post['likes'] ?? []);
    final postOwnerId = post['user_id'];

    final wasLiked = likes.contains(currentUser.id);

    if (wasLiked) {
      likes.remove(currentUser.id);
    } else {
      likes.add(currentUser.id);
    }

    await _supabase.from('posts').update({'likes': likes}).eq('id', postId);

    // Send notification to post owner if someone else liked their post
    if (!wasLiked && postOwnerId != currentUser.id) {
      try {
        // Get the current user's name
        final userData = await _supabase
            .from('users')
            .select('name')
            .eq('id', currentUser.id)
            .single();
        final userName = userData['name'] ?? 'Someone';

        final notificationService = NotificationService();
        await notificationService.sendPushNotification(
          userId: postOwnerId,
          title: 'New Like',
          body: '$userName liked your post',
          data: {'postId': postId, 'type': 'like', 'fromUserId': currentUser.id},
        );
      } catch (e) {
        print('Error sending like notification: $e');
      }
    }
  }

  // Add comment to a post
  Future<void> addComment(String postId, String commentText) async {
    print('DEBUG: addComment called for postId: $postId, commentText: $commentText');
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      print('DEBUG: addComment failed - no authenticated user');
      return;
    }

    final comment = {
      'user_id': currentUser.id,
      'comment': commentText,
      'created_at': DateTime.now().toIso8601String(),
    };

    print('DEBUG: addComment - created comment object: $comment');

    // Get current comments and post owner
    final post = await _supabase.from('posts').select('comments, user_id').eq('id', postId).single();
    final comments = List<Map<String, dynamic>>.from(post['comments'] ?? []);
    final postOwnerId = post['user_id'];

    print('DEBUG: addComment - current comments count: ${comments.length}, postOwnerId: $postOwnerId');

    comments.add(comment);

    print('DEBUG: addComment - updating post with ${comments.length} comments');

    await _supabase.from('posts').update({'comments': comments}).eq('id', postId);

    print('DEBUG: addComment - successfully updated post in Supabase posts table');

    // Send notification to post owner if someone else commented on their post
    if (postOwnerId != currentUser.id) {
      try {
        // Get the current user's name
        final userData = await _supabase
            .from('users')
            .select('name')
            .eq('id', currentUser.id)
            .single();
        final userName = userData['name'] ?? 'Someone';

        final notificationService = NotificationService();
        await notificationService.sendPushNotification(
          userId: postOwnerId,
          title: 'New Comment',
          body: '$userName commented on your post',
          data: {'postId': postId, 'type': 'comment', 'fromUserId': currentUser.id},
        );
      } catch (e) {
        print('Error sending comment notification: $e');
      }
    }
  }

  // Share a post
  Future<void> sharePost(String postId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    // Get current shares count and post owner
    final post = await _supabase.from('posts').select('shares, user_id').eq('id', postId).single();
    final currentShares = post['shares'] as int? ?? 0;
    final postOwnerId = post['user_id'];

    // Increment shares count
    await _supabase.from('posts').update({'shares': currentShares + 1}).eq('id', postId);

    // Send notification to post owner if someone else shared their post
    if (postOwnerId != currentUser.id) {
      try {
        // Get the current user's name
        final userData = await _supabase
            .from('users')
            .select('name')
            .eq('id', currentUser.id)
            .single();
        final userName = userData['name'] ?? 'Someone';

        final notificationService = NotificationService();
        await notificationService.sendPushNotification(
          userId: postOwnerId,
          title: 'Post Shared',
          body: '$userName shared your post',
          data: {'postId': postId, 'type': 'share', 'fromUserId': currentUser.id},
        );
      } catch (e) {
        print('Error sending share notification: $e');
      }
    }
  }

  // Get specific post
  Future<Map<String, dynamic>?> getPost(String postId) async {
    try {
      final response = await _supabase.from('posts').select('*').eq('id', postId).single();
      return response;
    } catch (e) {
      print('Error getting post: $e');
      return null;
    }
  }

  // Get user profile for posts
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _supabase.from('users').select('*').eq('id', userId).single();
      return response;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Upload image for community post (using Supabase storage)
  Future<String?> uploadCommunityImage(File imageFile) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return null;

      final fileName =
          'community_images/${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Supabase storage
      await _supabase.storage.from('posts').upload(fileName, imageFile);
      final url = _supabase.storage.from('posts').getPublicUrl(fileName);
      return url;
    } catch (e) {
      print('Error uploading community image: $e');
      return null;
    }
  }

  // Get community statistics
  Future<Map<String, dynamic>> getCommunityStats() async {
    try {
      final postsResponse = await _supabase.from('posts').select('post_type');
      final usersResponse = await _supabase.from('users').select('id');

      int totalPosts = postsResponse.length;
      int totalUsers = usersResponse.length;
      int totalPrayers = 0;
      int totalVerses = 0;
      int totalReflections = 0;

      for (var post in postsResponse) {
        final postType = post['post_type'] as String?;
        switch (postType) {
          case 'prayer':
            totalPrayers++;
            break;
          case 'verse':
            totalVerses++;
            break;
          case 'reflection':
            totalReflections++;
            break;
        }
      }

      return {
        'totalPosts': totalPosts,
        'totalUsers': totalUsers,
        'totalPrayers': totalPrayers,
        'totalVerses': totalVerses,
        'totalReflections': totalReflections,
      };
    } catch (e) {
      print('Error getting community stats: $e');
      return {
        'totalPosts': 0,
        'totalUsers': 0,
        'totalPrayers': 0,
        'totalVerses': 0,
        'totalReflections': 0,
      };
    }
  }

  // Search community posts
  Future<List<Map<String, dynamic>>> searchCommunityPosts(String searchQuery) async {
    if (searchQuery.isEmpty) {
      final posts = await getCommunityPosts().first;
      return posts;
    }

    try {
      final response = await _supabase
          .from('posts')
          .select('*')
          .ilike('content', '%$searchQuery%')
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error searching community posts: $e');
      return [];
    }
  }

  // Get trending posts (most liked/commented)
  Future<List<Map<String, dynamic>>> getTrendingPosts() async {
    try {
      final response = await _supabase
          .from('posts')
          .select('*')
          .order('likes', ascending: false)
          .limit(10);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting trending posts: $e');
      return [];
    }
  }

  // Report inappropriate content
  Future<void> reportPost(String postId, String reason) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      await _supabase.from('reports').insert({
        'post_id': postId,
        'reported_by': currentUser.id,
        'reason': reason,
        'status': 'pending',
      });
    } catch (e) {
      print('Error reporting post: $e');
    }
  }

  // Get user's own posts
  Future<List<Map<String, dynamic>>> getUserPosts(String userId) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting user posts: $e');
      return [];
    }
  }

  // Delete user's own post
  Future<void> deletePost(String postId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Check if user owns the post
      final post = await _supabase.from('posts').select('user_id').eq('id', postId).single();
      if (post['user_id'] == currentUser.id) {
        await _supabase.from('posts').delete().eq('id', postId);
      }
    } catch (e) {
      print('Error deleting post: $e');
    }
  }

  // Update post
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Check if user owns the post
      final post = await _supabase.from('posts').select('user_id').eq('id', postId).single();
      if (post['user_id'] == currentUser.id) {
        updates['updated_at'] = DateTime.now().toIso8601String();
        await _supabase.from('posts').update(updates).eq('id', postId);
      }
    } catch (e) {
      print('Error updating post: $e');
    }
  }
}
