import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

// Mock classes for compatibility with existing code
class MockQueryDocumentSnapshot {
  final String id;
  final Map<String, dynamic> _data;

  MockQueryDocumentSnapshot(this.id, this._data);

  Map<String, dynamic> data() => _data;
  dynamic operator [](String key) => _data[key];
}

class MockQuerySnapshot {
  final List<MockQueryDocumentSnapshot> docs;

  MockQuerySnapshot(this.docs);

  int get size => docs.length;
}

class PostService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Create a new post
  Future<void> createPost({
    required String content,
    String? imageUrl,
    String? videoUrl,
    String? type, // 'text', 'image', 'video', 'story'
  }) async {
    try {
      print(
        'DEBUG: createPost called with content: $content, videoUrl: $videoUrl, type: $type',
      );
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('DEBUG: Error: No authenticated user');
        return;
      }

      print('DEBUG: Current user ID: ${user.id}');
      print('DEBUG: Current user email: ${user.email}');

      print('DEBUG: Fetching user info for post creation');
      // Fetch user info to include in post data
      final userService = UserService();
      final userInfo = await userService.getUserInfo();
      print('DEBUG: User info retrieved: $userInfo');

      // Determine post type - if it's 'story', save to stories table, otherwise to posts table
      if (type == 'story') {
        print('DEBUG: Creating story in Supabase stories table');
        final storyData = {
          'user_id': user.id,
          'content': content,
          'image_url': imageUrl,
          'video_url': videoUrl,
          'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        };

        final response = await _supabase.from('stories').insert(storyData).select();
        print('DEBUG: Story created successfully: ${response}');
      } else {
        print('DEBUG: Creating post in Supabase posts table');
        final postData = {
          'user_id': user.id,
          'content': content,
          'post_type': type ?? 'general',
          'image_url': imageUrl,
          'video_url': videoUrl,
        };

        final response = await _supabase.from('posts').insert(postData).select();
        print('DEBUG: Post created successfully: ${response}');
      }

      print('DEBUG: createPost completed successfully');
    } catch (e) {
      print('DEBUG: Error creating post: $e');
      print('DEBUG: Stack trace: ${e.toString()}');
      rethrow; // Re-throw to let the UI handle the error
    }
  }

  // Get all posts for home feed (excluding stories)
  Stream<MockQuerySnapshot> getHomeFeedPosts() {
    final controller = StreamController<MockQuerySnapshot>();

    // Initial fetch
    _fetchPosts().then((posts) {
      if (!controller.isClosed) {
        controller.add(posts);
      }
    });

    // Poll every 5 seconds for updates
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }

      try {
        final posts = await _fetchPosts();
        controller.add(posts);
      } catch (e) {
        print('Error fetching posts: $e');
      }
    });

    return controller.stream;
  }

  Future<MockQuerySnapshot> _fetchPosts() async {
    try {
      final response = await _supabase
          .from('posts')
          .select('*, user_id, content, post_type, image_url, video_url, created_at, updated_at, likes, comments, shares')
          .neq('post_type', 'story') // Exclude stories
          .order('created_at', ascending: false);

      final docs = (response as List).map((item) {
        final data = Map<String, dynamic>.from(item);
        // Normalize field names for compatibility
        final normalizedData = {
          ...data,
          'id': data['id'].toString(),
          'userId': data['user_id'],
          'postType': data['post_type'],
          'imageUrl': data['image_url'],
          'videoUrl': data['video_url'],
          'createdAt': data['created_at'],
          'updatedAt': data['updated_at'],
          'type': data['post_type'],
        };
        return MockQueryDocumentSnapshot(data['id'].toString(), normalizedData);
      }).toList();

      return MockQuerySnapshot(docs);
    } catch (e) {
      print('Error fetching posts: $e');
      return MockQuerySnapshot([]);
    }
  }

  // Get content videos for TikTok-style feed
  Stream<MockQuerySnapshot> getContentVideos() {
    final controller = StreamController<MockQuerySnapshot>();

    // Initial fetch
    _fetchVideos().then((videos) {
      if (!controller.isClosed) {
        controller.add(videos);
      }
    });

    // Poll every 5 seconds for updates
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }

      try {
        final videos = await _fetchVideos();
        controller.add(videos);
      } catch (e) {
        print('Error fetching videos: $e');
      }
    });

    return controller.stream;
  }

  Future<MockQuerySnapshot> _fetchVideos() async {
    try {
      final response = await _supabase
          .from('posts')
          .select('*, user_id, content, post_type, image_url, video_url, created_at, source')
          .neq('post_type', 'story')
          .eq('source', 'tiktok') // Only show videos created from TikTok feed
          .order('created_at', ascending: false);

      final videoPosts = (response as List).where((item) {
        final data = Map<String, dynamic>.from(item);
        final postType = data['post_type'];
        final videoUrl = data['video_url']?.toString() ?? '';
        return postType == 'video' && videoUrl.isNotEmpty;
      }).toList();

      // Get unique user IDs
      final userIds = videoPosts.map((post) => post['user_id']).where((id) => id != null).toSet().toList();

      print('DEBUG: Found user IDs from videoPosts: ${videoPosts.map((post) => post['user_id']).toList()}');
      print('DEBUG: Combined user IDs: $userIds');

      // Fetch user data for all users
      Map<String, Map<String, dynamic>> userDataMap = {};
      if (userIds.isNotEmpty) {
        final usersResponse = await _supabase
            .from('users')
            .select('id, name, profile_picture_url')
            .filter('id', 'in', '(${userIds.map((id) => '"$id"').join(',')})');

        print('DEBUG: Users response: $usersResponse');

        // For now, just use the name field from users table
        // New signups will have full names, existing users have usernames
        for (final user in usersResponse) {
          userDataMap[user['id']] = user;
        }
      }
      print('DEBUG: User data map: $userDataMap');

      final docs = videoPosts.map((item) {
        final data = Map<String, dynamic>.from(item);
        final userId = data['user_id'];
        final userData = userDataMap[userId] ?? {};

        // Normalize fields for TikTokFeedScreen
        final normalizedData = {
          ...data,
          'id': data['id'].toString(),
          'videoUrl': data['video_url'],
          'description': data['content'] ?? '',
          'userName': userData['name'] ?? 'User',
          'full_name': userData['full_name'] ?? userData['name'] ?? 'User',
          'profilePictureUrl': userData['profile_picture_url'] ?? '',
          'user_id': userId,
          'isFollowing': false,
          'timestamp': data['created_at'],
        };
        return MockQueryDocumentSnapshot(data['id'].toString(), normalizedData);
      }).toList();

      print('DEBUG: Fetched ${docs.length} videos with user data');
      return MockQuerySnapshot(docs);
    } catch (e) {
      print('Error fetching videos: $e');
      return MockQuerySnapshot([]);
    }
  }

  // Get posts from followed users (simplified for now)
  Stream<MockQuerySnapshot> getFollowedUsersPosts() {
    // TODO: Implement following system in Supabase
    return Stream.value(MockQuerySnapshot([]));
  }

  // Get stories for home feed
  Stream<MockQuerySnapshot> getStories() {
    final controller = StreamController<MockQuerySnapshot>();

    // Initial fetch
    _fetchStories().then((stories) {
      if (!controller.isClosed) {
        controller.add(stories);
      }
    });

    // Poll every 10 seconds for updates (stories don't change as frequently)
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }

      try {
        final stories = await _fetchStories();
        controller.add(stories);
      } catch (e) {
        print('Error fetching stories: $e');
      }
    });

    return controller.stream;
  }

  Future<MockQuerySnapshot> _fetchStories() async {
    try {
      final now = DateTime.now().toIso8601String();
      print('DEBUG: _fetchStories - Current time (now): $now');

      // Fetch stories without join to avoid foreign key requirement
      final response = await _supabase
          .from('stories')
          .select('*')
          .gt('expires_at', now)
          .order('expires_at', ascending: false);

      print('DEBUG: _fetchStories - Raw response from stories query: $response');
      print('DEBUG: _fetchStories - Number of stories returned: ${response.length}');

      // Get unique user IDs
      final userIds = (response as List).map((story) => story['user_id']).where((id) => id != null).toSet().toList();
      print('DEBUG: _fetchStories - User IDs from stories: $userIds');

      // Fetch user data separately
      Map<String, Map<String, dynamic>> userDataMap = {};
      if (userIds.isNotEmpty) {
        final usersResponse = await _supabase
            .from('users')
            .select('id, name, profile_picture_url')
            .filter('id', 'in', '(${userIds.map((id) => '"$id"').join(',')})');

        print('DEBUG: _fetchStories - Users response: $usersResponse');

        for (final user in usersResponse) {
          userDataMap[user['id']] = user;
        }
      }
      print('DEBUG: _fetchStories - User data map: $userDataMap');

      final docs = (response as List).map((item) {
        final data = Map<String, dynamic>.from(item);
        print('DEBUG: _fetchStories - Processing story item: $data');
        final userId = data['user_id'];
        final userData = userDataMap[userId] ?? {};

        // Normalize fields for story display
        final normalizedData = {
          ...data,
          'id': data['id'].toString(),
          'userId': data['user_id'],
          'content': data['content'] ?? '',
          'imageUrl': data['image_url'] ?? '',
          'videoUrl': data['video_url'] ?? '',
          'timestamp': Timestamp.fromDate(DateTime.parse(data['created_at'])),
          'expiresAt': data['expires_at'],
          'username': userData['name'] ?? 'User',
          'profilePictureUrl': userData['profile_picture_url'] ?? '',
        };
        return MockQueryDocumentSnapshot(data['id'].toString(), normalizedData);
      }).toList();

      print('DEBUG: Fetched ${docs.length} active stories');
      if (docs.isNotEmpty) {
        print('DEBUG: Sample story data: ${docs.first.data()}');
      }

      return MockQuerySnapshot(docs);
    } catch (e) {
      print('Error fetching stories: $e');
      return MockQuerySnapshot([]);
    }
  }

  // Get posts by a specific user
  Stream<MockQuerySnapshot> getUserPosts(String userId) {
    final controller = StreamController<MockQuerySnapshot>();

    // Initial fetch
    _fetchUserPosts(userId).then((posts) {
      if (!controller.isClosed) {
        controller.add(posts);
      }
    });

    // Poll every 10 seconds
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }

      try {
        final posts = await _fetchUserPosts(userId);
        controller.add(posts);
      } catch (e) {
        print('Error fetching user posts: $e');
      }
    });

    return controller.stream;
  }

  Future<MockQuerySnapshot> _fetchUserPosts(String userId) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final docs = (response as List).map((item) {
        final data = Map<String, dynamic>.from(item);
        final normalizedData = {
          ...data,
          'id': data['id'].toString(),
          'userId': data['user_id'],
          'postType': data['post_type'],
          'imageUrl': data['image_url'],
          'videoUrl': data['video_url'],
          'createdAt': data['created_at'],
          'updatedAt': data['updated_at'],
        };
        return MockQueryDocumentSnapshot(data['id'].toString(), normalizedData);
      }).toList();

      return MockQuerySnapshot(docs);
    } catch (e) {
      print('Error fetching user posts: $e');
      return MockQuerySnapshot([]);
    }
  }

  // Get stories by a specific user
  Stream<MockQuerySnapshot> getUserStories(String userId) {
    final controller = StreamController<MockQuerySnapshot>();

    // Initial fetch
    _fetchUserStories(userId).then((stories) {
      if (!controller.isClosed) {
        controller.add(stories);
      }
    });

    // Poll every 10 seconds
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }

      try {
        final stories = await _fetchUserStories(userId);
        controller.add(stories);
      } catch (e) {
        print('Error fetching user stories: $e');
      }
    });

    return controller.stream;
  }

  Future<MockQuerySnapshot> _fetchUserStories(String userId) async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from('stories')
          .select('*')
          .eq('user_id', userId)
          .gt('expires_at', now)
          .order('expires_at', ascending: false);

      // Get user data for the stories
      final userResponse = await _supabase
          .from('users')
          .select('id, name, profile_picture_url')
          .eq('id', userId)
          .single();

      final userData = userResponse;

      final docs = (response as List).map((item) {
        final data = Map<String, dynamic>.from(item);
        final normalizedData = {
          ...data,
          'id': data['id'].toString(),
          'userId': data['user_id'],
          'content': data['content'] ?? '',
          'imageUrl': data['image_url'] ?? '',
          'videoUrl': data['video_url'] ?? '',
          'timestamp': data['created_at'],
          'expiresAt': data['expires_at'],
          'authorName': userData['name'] ?? 'User',
          'authorProfilePicture': userData['profile_picture_url'] ?? '',
        };
        return MockQueryDocumentSnapshot(data['id'].toString(), normalizedData);
      }).toList();

      return MockQuerySnapshot(docs);
    } catch (e) {
      print('Error fetching user stories: $e');
      return MockQuerySnapshot([]);
    }
  }

  // Like a post
  Future<void> likePost(String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    print('DEBUG likePost: Starting like operation for post $postId by user ${user.id}');

    try {
      // Check if user already liked this post
      final existingLike = await _supabase
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', user.id)
          .maybeSingle();

      print('DEBUG likePost: Existing like check result: ${existingLike != null}');

      if (existingLike != null) {
        // Unlike - remove the like
        print('DEBUG likePost: Removing existing like');
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id);

        // Decrement likes count
        await _supabase
            .from('posts')
            .update({'likes': 'likes - 1'})
            .eq('id', postId);

        print('DEBUG likePost: Unlike operation completed');
      } else {
        // Like - add the like
        print('DEBUG likePost: Adding new like');
        await _supabase
            .from('post_likes')
            .insert({
              'post_id': postId,
              'user_id': user.id,
              'created_at': DateTime.now().toIso8601String(),
            });

        // Increment likes count
        await _supabase
            .from('posts')
            .update({'likes': 'likes + 1'})
            .eq('id', postId);

        // Get post author to create notification
        print('DEBUG likePost: Fetching post author for notification');
        final post = await _supabase
            .from('posts')
            .select('user_id')
            .eq('id', postId)
            .single();

        final postAuthorId = post['user_id'];
        print('DEBUG likePost: Post author ID: $postAuthorId, current user: ${user.id}');

        // Don't notify if user is liking their own post
        if (postAuthorId != user.id) {
          // Get current user's name for notification
          final userService = UserService();
          final currentUserData = await userService.getUserInfo();
          final currentUserName = currentUserData?['name'] ?? 'Someone';

          print('DEBUG likePost: Creating notification for post author $postAuthorId from $currentUserName');

          // Create notification for post author
          await _supabase.from('notifications').insert({
            'user_id': postAuthorId,
            'type': 'like',
            'from_user_id': user.id,
            'message': '$currentUserName liked your post',
            'data': {'post_id': postId},
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });

          print('DEBUG likePost: Notification created successfully');
        } else {
          print('DEBUG likePost: Skipping notification - user liked their own post');
        }

        print('DEBUG likePost: Like operation completed');
      }
    } catch (e) {
      print('Error toggling like: $e');
      rethrow;
    }
  }

  // Check if current user liked a post
  Future<bool> isPostLiked(String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final like = await _supabase
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', user.id)
          .maybeSingle();

      return like != null;
    } catch (e) {
      print('Error checking if post is liked: $e');
      return false;
    }
  }

  // Add comment to a post
  Future<void> addComment(String postId, String comment) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Get current comments array
      final currentPost = await _supabase
          .from('posts')
          .select('comments')
          .eq('id', postId)
          .single();

      final currentComments = (currentPost['comments'] as List?) ?? [];

      // Create new comment object
      final newComment = {
        'user_id': user.id,
        'comment': comment,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Append new comment to array
      final updatedComments = [...currentComments, newComment];

      // Update the posts table with the new comments array
      await _supabase
          .from('posts')
          .update({'comments': updatedComments})
          .eq('id', postId);
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  // Get comments for a post
  Stream<MockQuerySnapshot> getPostComments(String postId) {
    final controller = StreamController<MockQuerySnapshot>();

    // Initial fetch
    _fetchComments(postId).then((comments) {
      if (!controller.isClosed) {
        controller.add(comments);
      }
    });

    // Poll every 5 seconds for updates
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }

      try {
        final comments = await _fetchComments(postId);
        controller.add(comments);
      } catch (e) {
        print('Error fetching comments: $e');
      }
    });

    return controller.stream;
  }

  Future<MockQuerySnapshot> _fetchComments(String postId) async {
    try {
      // Get the post to access the comments array
      final post = await _supabase
          .from('posts')
          .select('comments')
          .eq('id', postId)
          .single();

      final commentsArray = (post['comments'] as List?) ?? [];

      final docs = commentsArray.map((comment) {
        final data = Map<String, dynamic>.from(comment);
        final normalizedData = {
          ...data,
          'id': data['user_id'].toString() + '_' + data['created_at'], // Create a unique ID
          'userId': data['user_id'],
          'comment': data['comment'],
          'timestamp': data['created_at'],
        };
        return MockQueryDocumentSnapshot(data['user_id'].toString() + '_' + data['created_at'], normalizedData);
      }).toList();

      return MockQuerySnapshot(docs);
    } catch (e) {
      print('Error fetching comments: $e');
      return MockQuerySnapshot([]);
    }
  }

  // Delete a post
  Future<void> deletePost(String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Check if user owns the post
      final post = await _supabase.from('posts').select('user_id').eq('id', postId).single();
      if (post['user_id'] == user.id) {
        await _supabase.from('posts').delete().eq('id', postId);
      }
    } catch (e) {
      print('Error deleting post: $e');
    }
  }

  // Share a post
  Future<void> sharePost(String postId) async {
    try {
      // Get current share count first, then update
      final currentPost = await _supabase
          .from('posts')
          .select('shares')
          .eq('id', postId)
          .single();

      final currentCount = (currentPost['shares'] as int?) ?? 0;
      await _supabase
          .from('posts')
          .update({'shares': currentCount + 1})
          .eq('id', postId);
    } catch (e) {
      print('Error sharing post: $e');
      rethrow;
    }
  }

  // Get recent posts
  Future<List<Map<String, dynamic>>> getRecentPosts({int limit = 5}) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting recent posts: $e');
      return [];
    }
  }

  // Search posts by content
  Future<List<Map<String, dynamic>>> searchPosts(String query) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('*')
          .ilike('content', '%$query%')
          .neq('post_type', 'story')
          .order('created_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error searching posts: $e');
      return [];
    }
  }
}
