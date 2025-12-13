import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../services/post_service.dart';
import '../services/community_service.dart';
import '../profile_screen.dart';
import '../full_screen_image_viewer.dart';

class PostWidget extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String postId;

  const PostWidget({
    super.key,
    required this.postData,
    required this.postId,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  final PostService _postService = PostService();
  final CommunityService _communityService = CommunityService();
  bool _isLiked = false;
  bool _isLoadingLike = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  String _userName = 'Unknown User';
  String _profilePicUrl = '';
  bool _isMuted = false;
  double _volume = 1.0;
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
    _initializeVideoIfNeeded();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _checkIfLiked() async {
    // Get current user ID from Supabase
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    // Check if current user ID is in the likes array from post data
    final likes = List<String>.from(widget.postData['likes'] ?? []);
    final liked = likes.contains(currentUser.id);

    if (mounted) {
      setState(() => _isLiked = liked);
    }
  }

  void _initializeVideoIfNeeded() {
    final videoUrl = widget.postData['videoUrl'];
    print('DEBUG: _initializeVideoIfNeeded called, videoUrl: $videoUrl');
    if (videoUrl != null && videoUrl.isNotEmpty) {
      print('DEBUG: Initializing video controller for URL: $videoUrl');
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          print('DEBUG: Video initialized successfully');
          if (mounted) {
            setState(() => _isVideoInitialized = true);
            _videoController!.setVolume(_isMuted ? 0.0 : _volume);
          }
        }).catchError((error) {
          print('Error initializing video: $error');
        });
    } else {
      print('DEBUG: No video URL found');
    }
  }

  Future<void> _loadUserInfo() async {
    final userId = widget.postData['userId'] ?? widget.postData['user_id'];
    if (userId == null || userId.isEmpty) return;

    try {
      final userData = await Supabase.instance.client
          .from('users')
          .select('name, profile_picture_url')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _userName = userData['name'] ?? 'Unknown User';
          _profilePicUrl = userData['profile_picture_url'] ?? '';
        });
      }
    } catch (e) {
      print('Error getting user profile: $e');
      // Keep default values
    }
  }

  Future<void> _toggleLike() async {
    if (_isLoadingLike) return;

    setState(() => _isLoadingLike = true);
    try {
      await _communityService.toggleLike(widget.postId);
      // Re-check if liked after toggle
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        // Get updated post data to check likes
        final updatedPost = await Supabase.instance.client
            .from('posts')
            .select('likes')
            .eq('id', widget.postId)
            .single();
        final likes = List<String>.from(updatedPost['likes'] ?? []);
        final liked = likes.contains(currentUser.id);
        if (mounted) {
          setState(() => _isLiked = liked);
        }
      }
    } catch (e) {
      print('Error toggling like: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLike = false);
      }
    }
  }

  void _toggleVideoPlayback() {
    if (_videoController != null && _isVideoInitialized) {
      setState(() {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
      });
    }
  }

  void _toggleMute() {
    if (_videoController != null && _isVideoInitialized) {
      setState(() {
        _isMuted = !_isMuted;
        _videoController!.setVolume(_isMuted ? 0.0 : _volume);
      });
    }
  }

  void _setVolume(double value) {
    if (_videoController != null && _isVideoInitialized) {
      setState(() {
        _volume = value;
        _videoController!.setVolume(_isMuted ? 0.0 : _volume);
      });
    }
  }

  void _showLikesDialog() async {
    try {
      final likes = List<String>.from(widget.postData['likes'] ?? []);
      if (likes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No likes yet')),
        );
        return;
      }

      // Get user details for each liker
      final List<Map<String, dynamic>> likers = [];
      for (final userId in likes) {
        try {
          final userData = await Supabase.instance.client
              .from('users')
              .select('name, profile_picture_url')
              .eq('id', userId)
              .single();
          likers.add({
            'id': userId,
            'name': userData['name'] ?? 'Unknown User',
            'profile_picture_url': userData['profile_picture_url'] ?? '',
          });
        } catch (e) {
          print('Error getting liker info for $userId: $e');
          likers.add({
            'id': userId,
            'name': 'Unknown User',
            'profile_picture_url': '',
          });
        }
      }

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('${likes.length} ${likes.length == 1 ? 'Like' : 'Likes'}'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: likers.length,
                itemBuilder: (context, index) {
                  final liker = likers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundImage: liker['profile_picture_url'].isNotEmpty
                          ? CachedNetworkImageProvider(liker['profile_picture_url'])
                          : null,
                      backgroundColor: const Color(0xFF1E3A8A),
                      child: liker['profile_picture_url'].isEmpty
                          ? Text(
                              liker['name'][0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            )
                          : null,
                    ),
                    title: Text(liker['name']),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Error showing likes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load likes')),
      );
    }
  }

  void _showCommentsView() async {
    try {
      final comments = List<Map<String, dynamic>>.from(widget.postData['comments'] ?? []);

      // Get user details for each commenter
      final List<Map<String, dynamic>> commentsWithUsers = [];
      for (final comment in comments) {
        final userId = comment['user_id'];
        try {
          final userData = await Supabase.instance.client
              .from('users')
              .select('name, profile_picture_url')
              .eq('id', userId)
              .single();
          commentsWithUsers.add({
            ...comment,
            'user_name': userData['name'] ?? 'Unknown User',
            'user_profile_pic': userData['profile_picture_url'] ?? '',
          });
        } catch (e) {
          print('Error getting commenter info for $userId: $e');
          commentsWithUsers.add({
            ...comment,
            'user_name': 'Unknown User',
            'user_profile_pic': '',
          });
        }
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          final TextEditingController commentController = TextEditingController();

          return StatefulBuilder(
            builder: (context, setState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.8,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${commentsWithUsers.length} ${commentsWithUsers.length == 1 ? 'Comment' : 'Comments'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: commentsWithUsers.isEmpty
                          ? const Center(
                              child: Text('No comments yet. Be the first to comment!'),
                            )
                          : ListView.builder(
                              itemCount: commentsWithUsers.length,
                              itemBuilder: (context, index) {
                                final comment = commentsWithUsers[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundImage: comment['user_profile_pic'].isNotEmpty
                                            ? CachedNetworkImageProvider(comment['user_profile_pic'])
                                            : null,
                                        backgroundColor: const Color(0xFF1E3A8A),
                                        child: comment['user_profile_pic'].isEmpty
                                            ? Text(
                                                comment['user_name'][0].toUpperCase(),
                                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              comment['user_name'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              comment['comment'],
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(),
                    // Comment input with emoji support
                    Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                                color: const Color(0xFF1E3A8A),
                              ),
                              onPressed: () {
                                setState(() {
                                  _showEmojiPicker = !_showEmojiPicker;
                                });
                              },
                              tooltip: 'Add emoji',
                            ),
                            Expanded(
                              child: TextField(
                                controller: commentController,
                                decoration: const InputDecoration(
                                  hintText: 'Write a comment...',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 3,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send, color: Color(0xFF1E3A8A)),
                              onPressed: () async {
                                final comment = commentController.text.trim();
                                if (comment.isNotEmpty) {
                                  try {
                                    await _communityService.addComment(widget.postId, comment);
                                    commentController.clear();
                                    // Refresh comments
                                    final rawComments = (await Supabase.instance.client
                                        .from('posts')
                                        .select('comments')
                                        .eq('id', widget.postId)
                                        .single())['comments'] ?? [];
                                    final updatedComments = List<Map<String, dynamic>>.from(
                                      (rawComments as List<dynamic>).map((comment) => Map<String, dynamic>.from(comment))
                                    );

                                    final List<Map<String, dynamic>> updatedCommentsWithUsers = [];
                                    for (final c in updatedComments) {
                                      final uid = c['user_id'];
                                      try {
                                        final ud = await Supabase.instance.client
                                            .from('users')
                                            .select('name, profile_picture_url')
                                            .eq('id', uid)
                                            .single();
                                        updatedCommentsWithUsers.add({
                                          ...c,
                                          'user_name': ud['name'] ?? 'Unknown User',
                                          'user_profile_pic': ud['profile_picture_url'] ?? '',
                                        });
                                      } catch (e) {
                                        updatedCommentsWithUsers.add({
                                          ...c,
                                          'user_name': 'Unknown User',
                                          'user_profile_pic': '',
                                        });
                                      }
                                    }

                                    setState(() {
                                      commentsWithUsers.clear();
                                      commentsWithUsers.addAll(updatedCommentsWithUsers);
                                    });

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Comment added successfully!')),
                                      );
                                    }
                                  } catch (e) {
                                    print('Error adding comment: $e');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Failed to add comment')),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        // Emoji picker
                        if (_showEmojiPicker)
                          SizedBox(
                            height: 250,
                            child: EmojiPicker(
                              onEmojiSelected: (category, emoji) {
                                commentController.text += emoji.emoji;
                                commentController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: commentController.text.length),
                                );
                              },
                              config: const Config(),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      print('Error showing comments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load comments')),
      );
    }
  }

  bool _isCurrentUserPostOwner() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return false;

    final postUserId = widget.postData['userId'] ?? widget.postData['user_id'];
    return postUserId == currentUser.id;
  }

  void _showPostOptionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isCurrentUserPostOwner())
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Post', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showDeleteConfirmationDialog();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.report),
                title: const Text('Report Post'),
                onTap: () {
                  Navigator.of(context).pop();
                  // TODO: Implement report functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report functionality coming soon')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deletePost();
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePost() async {
    try {
      await _communityService.deletePost(widget.postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
        // The parent widget (facebook_home_screen) will handle removing this post from the list
        // since it uses a StreamBuilder that will automatically update when the post is deleted
      }
    } catch (e) {
      print('Error deleting post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete post')),
        );
      }
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final postTime = timestamp.toDate();
    final difference = now.difference(postTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final postData = widget.postData;
    final username = _userName;
    final profilePicUrl = _profilePicUrl;
    final content = postData['content'] ?? '';
    final imageUrl = postData['imageUrl'];
    final videoUrl = postData['videoUrl'];
    final likes = (postData['likes'] as List?)?.length ?? 0;
    final comments = (postData['comments'] as List?)?.length ?? 0;
    final shares = postData['shares'] ?? 0;
    final timestamp = postData['timestamp'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info and timestamp
            GestureDetector(
              onTap: () {
                final postUserId = widget.postData['userId'] ?? widget.postData['user_id'];
                final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                final isOwnProfile = postUserId == currentUserId;

                print('DEBUG: Profile tapped for user: $postUserId, username: $username, isOwnProfile: $isOwnProfile');

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      userId: postUserId,
                      showFullProfile: !isOwnProfile, // Show full profile only for other users
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: profilePicUrl.isNotEmpty
                        ? CachedNetworkImageProvider(profilePicUrl)
                        : null,
                    backgroundColor: const Color(0xFF1E3A8A),
                    child: profilePicUrl.isEmpty
                        ? Text(
                            username[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: _showPostOptionsMenu,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            // Image display
            (imageUrl != null && imageUrl.isNotEmpty) ? Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: 350,
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenImageViewer(
                          imageUrl: imageUrl,
                          heroTag: 'post-image-${widget.postId}',
                        ),
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'post-image-${widget.postId}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ) : const SizedBox.shrink(),

            // Video display
            (videoUrl != null && videoUrl.isNotEmpty) ? Container(
              width: double.infinity,
              height: 250, // Fixed height for consistent display
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isVideoInitialized && _videoController != null
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: _toggleVideoPlayback,
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _videoController!.value.size.width,
                                  height: _videoController!.value.size.height,
                                  child: VideoPlayer(_videoController!),
                                ),
                              ),
                            ),
                          ),
                          if (!_videoController!.value.isPlaying)
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
                                      _videoController!.value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      ),
                                    onPressed: _toggleVideoPlayback,
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _isMuted ? Icons.volume_off : Icons.volume_up,
                                      color: Colors.white,
                                      ),
                                    onPressed: _toggleMute,
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _isMuted ? 0.0 : _volume,
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: (value) {
                                        _setVolume(value);
                                      },
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
              ),
            ) : const SizedBox.shrink(),

            // Post content (caption)
            (content.isNotEmpty) ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                content,
                style: const TextStyle(fontSize: 14),
              ),
            ) : const SizedBox.shrink(),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _isLoadingLike ? null : _toggleLike,
                        icon: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.red : Colors.grey,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _showLikesDialog,
                          child: Text(
                            '$likes',
                            style: TextStyle(
                              color: _isLiked ? Colors.red : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _showCommentsView,
                        icon: const Icon(
                          Icons.comment_outlined,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _showCommentsView,
                          child: Text(
                            '$comments',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      try {
                        // Share the post content
                        final postType = widget.postData['post_type'] ?? 'post';
                        final shareText = 'Check out this $postType by $_userName:\n\n"${content}"';
                        await Share.share(shareText, subject: '${postType.toUpperCase()} from $_userName');

                        // Also increment share count
                        await _communityService.sharePost(widget.postId);
                        // Show success message
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Post shared successfully!')),
                          );
                        }
                      } catch (e) {
                        print('Error sharing post: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to share post')),
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.share_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                    label: Text(
                      '$shares',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
