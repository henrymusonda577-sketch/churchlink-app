import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'create_post_screen.dart';
import 'services/community_service.dart';
import 'services/supabase_chat_service.dart';
import 'package:share_plus/share_plus.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final CommunityService _communityService = CommunityService();
  final SupabaseChatService _chatService = SupabaseChatService();
  Stream<List<Map<String, dynamic>>>? _postsStream;
  Map<String, Map<String, dynamic>> _userProfiles = {};
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Like state per post
  Set<String> _liked = {};

  // Video playback state per post
  Map<String, VideoPlayerController?> _videoControllers = {};
  Map<String, bool> _videoInitialized = {};
  Map<String, bool> _videoMuted = {};
  Map<String, double> _videoVolumes = {};

  @override
  void initState() {
    super.initState();
    _initializePosts();
  }

  void _initializePosts() {
    if (_searchQuery.isNotEmpty) {
      // For search, we'll use a stream that emits the search results
      _postsStream = Stream.fromFuture(
        _communityService.searchCommunityPosts(_searchQuery)
      );
    } else {
      _postsStream =
          _communityService.getCommunityPosts(postType: _selectedFilter);
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    if (_userProfiles.containsKey(userId)) return;

    try {
      final profile = await _communityService.getUserProfile(userId);
      if (profile != null) {
        setState(() {
          _userProfiles[userId] = profile;
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _toggleLike(String postId) async {
    try {
      await _communityService.toggleLike(postId);
      // Force refresh to update like state immediately
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling like: $e')),
        );
      }
    }
  }

  Future<void> _addComment(String postId, String commentText) async {
    print('DEBUG: _addComment called for postId: $postId, commentText: "$commentText"');
    if (commentText.trim().isEmpty) {
      print('DEBUG: _addComment - comment text is empty, returning');
      return;
    }

    try {
      print('DEBUG: _addComment - calling _communityService.addComment');
      await _communityService.addComment(postId, commentText);
      print('DEBUG: _addComment - successfully added comment');
    } catch (e) {
      print('DEBUG: _addComment - error adding comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')),
        );
      }
    }
  }

  void _showCommentDialog(String postId) {
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(
            hintText: 'Write a comment...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _addComment(postId, commentController.text);
              Navigator.pop(context);
            },
            child: const Text('Comment'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarForegroundColor = Theme.of(context).appBarTheme.foregroundColor ?? Colors.white;
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search posts...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: _onSearchChanged,
              )
            : const Text('Community'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: appBarForegroundColor,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CreatePostScreen()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                 FilterChip(
                   label: const Text('All'),
                   selected: _selectedFilter == 'all',
                   onSelected: (_) => _onFilterChanged('all'),
                   backgroundColor: Colors.transparent,
                   selectedColor: Colors.blue.withOpacity(0.3),
                   checkmarkColor: Colors.white,
                   side: const BorderSide(color: Colors.black, width: 1),
                   labelStyle: const TextStyle(color: Colors.black),
                 ),
                 const SizedBox(width: 8),
                 FilterChip(
                   label: const Text('Prayers'),
                   selected: _selectedFilter == 'prayer',
                   onSelected: (_) => _onFilterChanged('prayer'),
                   backgroundColor: Colors.transparent,
                   selectedColor: Colors.blue.withOpacity(0.3),
                   checkmarkColor: Colors.white,
                   side: const BorderSide(color: Colors.black, width: 1),
                   labelStyle: const TextStyle(color: Colors.black),
                 ),
                 const SizedBox(width: 8),
                 FilterChip(
                   label: const Text('Verses'),
                   selected: _selectedFilter == 'verse',
                   onSelected: (_) => _onFilterChanged('verse'),
                   backgroundColor: Colors.transparent,
                   selectedColor: Colors.blue.withOpacity(0.3),
                   checkmarkColor: Colors.white,
                   side: const BorderSide(color: Colors.black, width: 1),
                   labelStyle: const TextStyle(color: Colors.black),
                 ),
                 const SizedBox(width: 8),
                 FilterChip(
                   label: const Text('Testimonies'),
                   selected: _selectedFilter == 'testimony',
                   onSelected: (_) => _onFilterChanged('testimony'),
                   backgroundColor: Colors.transparent,
                   selectedColor: Colors.blue.withOpacity(0.3),
                   checkmarkColor: Colors.white,
                   side: const BorderSide(color: Colors.black, width: 1),
                   labelStyle: const TextStyle(color: Colors.black),
                 ),
                 const SizedBox(width: 8),
                 FilterChip(
                   label: const Text('General'),
                   selected: _selectedFilter == 'general',
                   onSelected: (_) => _onFilterChanged('general'),
                   backgroundColor: Colors.transparent,
                   selectedColor: Colors.blue.withOpacity(0.3),
                   checkmarkColor: Colors.white,
                   side: const BorderSide(color: Colors.black, width: 1),
                   labelStyle: const TextStyle(color: Colors.black),
                 ),
               ],
             ),
           ),
         ),
       ),
     ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 80, color: Colors.red),
                  const SizedBox(height: 20),
                  const Text(
                    'Error loading posts',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => setState(() => _initializePosts()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final allPosts = snapshot.data ?? [];
          final posts = _selectedFilter == 'all'
              ? allPosts
              : allPosts.where((post) => post['post_type'] == _selectedFilter).toList();

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people, size: 80, color: Color(0xFF1E3A8A)),
                  const SizedBox(height: 20),
                  const Text(
                    'No Community Posts Yet',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Be the first to share with your community!',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CreatePostScreen()),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Post'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() => _initializePosts()),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length + 1,
              itemBuilder: (context, index) {
                if (index == posts.length) {
                  // End of feed prompt
                  return Container(
                    margin: const EdgeInsets.only(top: 16, bottom: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.post_add,
                          size: 64,
                          color: Color(0xFF1E3A8A),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "You've reached the end!",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Post your thoughts and share your faith with the community",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreatePostScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Post'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final post = posts[index];
                final postId = post['id'] as String?;
                final userId = post['user_id'] as String?;
                if (postId == null) return const SizedBox.shrink(); // Skip posts without ID

                // Load user profile if not already loaded
                if (userId != null && !_userProfiles.containsKey(userId)) {
                  _loadUserProfile(userId);
                }

                final userProfile = _userProfiles[userId];
                final authorName = userProfile?['name'] ??
                    userProfile?['email']?.split('@')[0] ??
                    'Anonymous';
                final likes = List<String>.from(post['likes'] ?? []);
                final comments = List<Map<String, dynamic>>.from(post['comments'] ?? []);
                final timestamp = DateTime.tryParse(post['created_at'] ?? '') ??
                    DateTime.now();

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF1E3A8A),
                              backgroundImage:
                                  userProfile?['profile_picture_url'] != null
                                      ? NetworkImage(
                                          userProfile!['profile_picture_url'])
                                      : null,
                              child: userProfile?['profile_picture_url'] == null
                                  ? Text(
                                      authorName[0].toUpperCase(),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authorName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _formatTimestamp(timestamp),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getTypeColor(
                                    post['post_type'] ?? 'general'),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                (post['post_type'] ?? 'general').toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          post['content'] ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (post['image_url'] != null && post['image_url'].isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              post['image_url'],
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(Icons.image_not_supported),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (post['video_url'] != null && post['video_url'].isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            height: 250, // Fixed height for consistent display
                            child: StatefulBuilder(
                              builder: (context, setState) {
                                // Initialize video if needed
                                if (!_videoControllers.containsKey(postId)) {
                                  _initializeVideoIfNeeded(postId!, post['video_url']);
                                }

                                final controller = _videoControllers[postId];
                                final isInitialized = _videoInitialized[postId] == true;

                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: isInitialized && controller != null
                                      ? Stack(
                                          children: [
                                            Positioned.fill(
                                              child: GestureDetector(
                                                onTap: () => _toggleVideoPlayback(postId!),
                                                child: FittedBox(
                                                  fit: BoxFit.cover,
                                                  child: SizedBox(
                                                    width: controller.value.size.width,
                                                    height: controller.value.size.height,
                                                    child: VideoPlayer(controller),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (!controller.value.isPlaying)
                                              Center(
                                                child: Container(
                                                  color: Colors.black26,
                                                  child: const Icon(
                                                    Icons.play_circle_fill,
                                                    size: 64,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            // Controls overlay
                                            Positioned(
                                              bottom: 0,
                                              left: 0,
                                              right: 0,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.bottomCenter,
                                                    end: Alignment.topCenter,
                                                    colors: [Colors.black54, Colors.transparent],
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(
                                                        controller.value.isPlaying
                                                            ? Icons.pause
                                                            : Icons.play_arrow,
                                                        color: Colors.white,
                                                      ),
                                                      onPressed: () => _toggleVideoPlayback(postId!),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(
                                                        (_videoMuted[postId] ?? false) ? Icons.volume_off : Icons.volume_up,
                                                        color: Colors.white,
                                                      ),
                                                      onPressed: () => _toggleVideoMute(postId!),
                                                    ),
                                                    Expanded(
                                                      child: Slider(
                                                        value: (_videoMuted[postId] ?? false) ? 0.0 : (_videoVolumes[postId] ?? 1.0),
                                                        min: 0.0,
                                                        max: 1.0,
                                                        onChanged: (value) => _setVideoVolume(postId!, value),
                                                        activeColor: Colors.white,
                                                        inactiveColor: Colors.white54,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Container(
                                          color: Colors.grey[300],
                                          child: const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _liked.contains(postId)
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border,
                                color: _liked.contains(postId)
                                    ? Colors.red
                                    : Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_liked.contains(postId)) {
                                    _liked.remove(postId);
                                  } else {
                                    _liked.add(postId);
                                  }
                                });
                              },
                            ),
                            Text('${likes.length}'),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.message, color: Colors.white),
                              onPressed: () => _showCommentDialog(postId),
                            ),
                            Text('${comments.length}'),
                            if (post['post_type'] == 'prayer') ...[
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () => _respondToPrayer(postId!),
                                icon: const Icon(Icons.message, size: 16),
                                label: const Text('Message'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                            const Spacer(),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                switch (value) {
                                  case 'report':
                                    await _reportPost(postId);
                                    break;
                                  case 'delete':
                                    await _deletePost(postId);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'report',
                                  child: Text('Report Post'),
                                ),
                                if (post['user_id'] == userId)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete Post'),
                                  ),
                              ],
                              icon: const Icon(Icons.more_vert),
                            ),
                            IconButton(
                              icon: const Icon(Icons.share),
                              onPressed: postId != null ? () async {
                                try {
                                  // Share the post content
                                  final shareText = 'Check out this ${post['post_type'] ?? 'post'} by $authorName:\n\n"${post['content'] ?? ''}"';
                                  await Share.share(shareText, subject: '${post['post_type']?.toUpperCase() ?? 'POST'} from $authorName');

                                  // Also increment share count
                                  await _communityService.sharePost(postId);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Post shared!')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('Error sharing: $e')),
                                    );
                                  }
                                }
                              } : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'prayer':
        return Colors.purple;
      case 'verse':
        return Colors.blue;
      case 'testimony':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _searchQuery = '';
      _searchController.clear();
      _isSearching = false;
    });
    _initializePosts();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _initializePosts();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
        _initializePosts();
      }
    });
  }

  Future<void> _reportPost(String postId) async {
    final reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for reporting this post:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for report...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _communityService.reportPost(
                    postId, reasonController.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post reported successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error reporting post: $e')),
                  );
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
            'Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _communityService.deletePost(postId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting post: $e')),
          );
        }
      }
    }
  }

  void _respondToPrayer(String postId) async {
    print('DEBUG: _respondToPrayer called for postId: $postId');

    // Get the post to find the author
    try {
      final post = await _communityService.getPost(postId);
      if (post == null) {
        print('DEBUG: _respondToPrayer - post not found');
        return;
      }

      final authorId = post['user_id'] as String?;
      if (authorId == null) {
        print('DEBUG: _respondToPrayer - post author not found');
        return;
      }

      print('DEBUG: _respondToPrayer - sending private message to author: $authorId');

      final responseController = TextEditingController();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send Private Message'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This will send a private message to the person who posted this prayer.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: responseController,
                decoration: const InputDecoration(
                  hintText: 'Share how you\'re praying or encouraging this person...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final message = responseController.text.trim();
                if (message.isEmpty) {
                  Navigator.pop(context);
                  return;
                }

                print('DEBUG: _respondToPrayer - sending private message: "$message" to user: $authorId');

                try {
                  await _chatService.sendMessage(
                    toUserId: authorId,
                    message: message,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Private message sent!')),
                    );
                  }
                } catch (e) {
                  print('DEBUG: _respondToPrayer - error sending message: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error sending message: $e')),
                    );
                  }
                }

                Navigator.pop(context);
              },
              child: const Text('Send Message'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('DEBUG: _respondToPrayer - error getting post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading prayer details: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Dispose all video controllers
    for (final controller in _videoControllers.values) {
      controller?.dispose();
    }
    _videoControllers.clear();
    _videoInitialized.clear();
    _videoMuted.clear();
    _videoVolumes.clear();
    super.dispose();
  }

  void _initializeVideoIfNeeded(String postId, String videoUrl) {
    if (_videoControllers.containsKey(postId)) return; // Already initialized

    print('DEBUG: CommunityScreen._initializeVideoIfNeeded called for postId: $postId, videoUrl: $videoUrl');
    if (videoUrl.isNotEmpty) {
      print('DEBUG: Initializing video controller for URL: $videoUrl');
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          print('DEBUG: Video initialized successfully for postId: $postId');
          if (mounted) {
            setState(() {
              _videoInitialized[postId] = true;
              _videoMuted[postId] = false;
              _videoVolumes[postId] = 1.0;
            });
          }
        }).catchError((error) {
          print('Error initializing video for postId $postId: $error');
        });
      _videoControllers[postId] = controller;
    } else {
      print('DEBUG: No video URL found for postId: $postId');
    }
  }

  void _toggleVideoPlayback(String postId) {
    final controller = _videoControllers[postId];
    if (controller != null && _videoInitialized[postId] == true) {
      setState(() {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      });
    }
  }

  void _toggleVideoMute(String postId) {
    final controller = _videoControllers[postId];
    if (controller != null && _videoInitialized[postId] == true) {
      setState(() {
        final isMuted = !(_videoMuted[postId] ?? false);
        _videoMuted[postId] = isMuted;
        controller.setVolume(isMuted ? 0.0 : (_videoVolumes[postId] ?? 1.0));
      });
    }
  }

  void _setVideoVolume(String postId, double value) {
    final controller = _videoControllers[postId];
    if (controller != null && _videoInitialized[postId] == true) {
      setState(() {
        _videoVolumes[postId] = value;
        controller.setVolume((_videoMuted[postId] ?? false) ? 0.0 : value);
      });
    }
  }
}
