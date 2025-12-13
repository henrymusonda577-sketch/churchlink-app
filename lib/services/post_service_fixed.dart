import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

// Mock QuerySnapshot to combine multiple query results
class _MockQuerySnapshot implements QuerySnapshot {
  final List<QueryDocumentSnapshot> _docs;

  _MockQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot> get docs => _docs;

  @override
  SnapshotMetadata get metadata => SnapshotMetadata();

  @override
  SnapshotMetadata get snapshotMetadata => SnapshotMetadata();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new post
  Future<void> createPost({
    required String content,
    String? imageUrl,
    String? videoUrl,
    String? type, // 'text', 'image', 'video', 'story'
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Error: No authenticated user');
        return;
      }

      final postData = {
        'userId': user.uid,
        'content': content,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'type': type ?? 'text',
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'timestamp': FieldValue.serverTimestamp(),
        'isStory': type == 'story',
        'storyExpiresAt': type == 'story'
            ? Timestamp.fromDate(DateTime.now().add(const Duration(hours: 23)))
            : null,
      };

      final postRef = await _firestore.collection('posts').add(postData);

      // Update user's post count
      await _firestore.collection('users').doc(user.uid).update({
        'posts': FieldValue.increment(1),
      });

      // If it's a story, also add to stories collection
      if (type == 'story') {
        await _firestore.collection('stories').add({
          'postId': postRef.id,
          'userId': user.uid,
          'content': content,
          'imageUrl': imageUrl,
          'videoUrl': videoUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'expiresAt':
              Timestamp.fromDate(DateTime.now().add(const Duration(hours: 23))),
        });
      }
    } catch (e) {
      print('Error creating post: $e');
      rethrow; // Re-throw to let the UI handle the error
    }
  }

  // Get all posts for home feed
  Stream<QuerySnapshot> getHomeFeedPosts() {
    return _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get content videos for TikTok-style feed
  Stream<QuerySnapshot> getContentVideos() {
    return _firestore
        .collection('posts')
        .where('type', isEqualTo: 'video')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get posts from followed users
  Stream<QuerySnapshot> getFollowedUsersPosts() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .switchMap((snapshot) {
      final following = List<String>.from(snapshot.data()?['following'] ?? []);
      if (following.isEmpty) {
        return Stream.empty();
      }

      // Firestore whereIn has a limit of 10 items, so we need to handle this
      if (following.length <= 10) {
        return _firestore
            .collection('posts')
            .where('userId', whereIn: following)
            .orderBy('timestamp', descending: true)
            .snapshots();
      } else {
        // For more than 10 following, split into batches of 10
        final batches = <List<String>>[];
        for (var i = 0; i < following.length; i += 10) {
          final end = (i + 10 < following.length) ? i + 10 : following.length;
          batches.add(following.sublist(i, end));
        }

        // Create streams for each batch
        final streams = batches.map((batch) {
          return _firestore
              .collection('posts')
              .where('userId', whereIn: batch)
              .orderBy('timestamp', descending: true)
              .snapshots();
        }).toList();

        // Combine all streams using RxDart's combineLatest
        return Rx.combineLatestList(streams).map((snapshots) {
          // Combine all documents from different snapshots
          final allDocs = <QueryDocumentSnapshot>[];
          for (final snapshot in snapshots) {
            allDocs.addAll(snapshot.docs);
          }

          // Sort by timestamp descending
          allDocs.sort((a, b) {
            final aTime =
                (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final bTime =
                (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          // Return a mock QuerySnapshot with combined docs
          return _MockQuerySnapshot(allDocs);
        });
      }
    });
  }

  // Get stories for home feed
  Stream<QuerySnapshot> getStories() {
    final now = Timestamp.now();
    return _firestore
        .collection('stories')
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: true)
        .snapshots();
  }

  // Get posts by a specific user
  Stream<QuerySnapshot> getUserPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get stories by a specific user
  Stream<QuerySnapshot> getUserStories(String userId) {
    final now = Timestamp.now();
    return _firestore
        .collection('stories')
        .where('userId', isEqualTo: userId)
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: true)
        .snapshots();
  }

  // Like a post
  Future<void> likePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final likeRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(user.uid);

    final likeDoc = await likeRef.get();

    if (likeDoc.exists) {
      // Unlike
      await likeRef.delete();
      await _firestore.collection('posts').doc(postId).update({
        'likes': FieldValue.increment(-1),
      });
    } else {
      // Like
      await likeRef.set({
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('posts').doc(postId).update({
        'likes': FieldValue.increment(1),
      });
    }
  }

  // Check if current user liked a post
  Future<bool> isPostLiked(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final likeDoc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(user.uid)
        .get();

    return likeDoc.exists;
  }

  // Add comment to a post
  Future<void> addComment(String postId, String comment) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add({
      'userId': user.uid,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update post comment count
    await _firestore.collection('posts').doc(postId).update({
      'comments': FieldValue.increment(1),
    });
  }

  // Get comments for a post
  Stream<QuerySnapshot> getPostComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Delete a post
  Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Check if user owns the post
    final postDoc = await _firestore.collection('posts').doc(postId).get();
    if (postDoc.data()?['userId'] != user.uid) return;

    // Delete the post
    await _firestore.collection('posts').doc(postId).delete();

    // Update user's post count
    await _firestore.collection('users').doc(user.uid).update({
      'posts': FieldValue.increment(-1),
    });
  }

  // Share a post
  Future<void> sharePost(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'shares': FieldValue.increment(1),
    });
  }

  // Get recent posts
  Future<List<Map<String, dynamic>>> getRecentPosts({int limit = 5}) async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting recent posts: $e');
      // Return empty list instead of throwing error
      return [];
    }
  }

  // Search posts by content
  Future<List<Map<String, dynamic>>> searchPosts(String query) async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .get();

      // Filter posts that contain the search query in their content and are not stories
      final filteredPosts = querySnapshot.docs
          .map((doc) => doc.data())
          .where((post) {
            final content = post['content']?.toString().toLowerCase() ?? '';
            final isStory = post['isStory'] ?? false;
            return content.contains(query.toLowerCase()) && !isStory;
          })
          .take(20) // Limit results to 20
          .toList();

      return filteredPosts;
    } catch (e) {
      print('Error searching posts: $e');
      return [];
    }
  }

  // Get current like count for a post
  Future<int> _getPostLikes(String postId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      return postDoc.data()?['likes'] ?? 0;
    } catch (e) {
      print('Error getting post likes: $e');
      return 0;
    }
  }
}
