import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'services/post_service.dart';
import 'services/video_cache_service.dart';
import 'widgets/safe_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'profile_screen.dart';
import 'create_post_screen.dart';
import 'services/user_service.dart';
import 'services/community_service.dart';

// Import mock classes from PostService
import 'services/post_service.dart' show MockQuerySnapshot, MockQueryDocumentSnapshot;

class TikTokFeedScreen extends StatefulWidget {
  const TikTokFeedScreen({Key? key}) : super(key: key);

  @override
  State<TikTokFeedScreen> createState() => TikTokFeedScreenState();
}

class TikTokFeedScreenState extends State<TikTokFeedScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  final PostService _postService = PostService();
  final VideoCacheService _videoCacheService = VideoCacheService();
  final UserService _userService = UserService();
  final CommunityService _communityService = CommunityService();
  final Map<String, VideoPlayerController> _controllers = {};
  final Set<String> _liked = {};
  final Map<String, bool> _followingStatus = {};

  final Map<String, int> _commentCounts = {};
  bool _showEmojiPicker = false;
  bool _isScreenVisible = false; // Initialize to false to prevent auto-play before visibility is confirmed
  bool _isAppInForeground = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _controllers.values) {
      try {
        c.dispose();
      } catch (_) {}
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (kDebugMode) {
      print('DEBUG: App lifecycle state changed: $state');
    }

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        _updateVideoPlayback();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _isAppInForeground = false;
        _pauseAllVideos();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _pauseAllVideos() {
    _controllers.forEach((videoUrl, controller) {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        controller.pause();
      }
    });
  }

  void pauseAllVideos() {
    _pauseAllVideos();
  }

  void _updateVideoPlayback() {
    if (_isAppInForeground && _isScreenVisible) {
      final currentPage = _pageController.page?.round() ?? 0;
      _controllers.forEach((videoUrl, controller) {
        if (controller.value.isInitialized && !controller.value.isPlaying) {
          controller.play().catchError((e) {
            if (kDebugMode) {
              print('Error resuming video playback: $e');
            }
          });
        }
      });
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visibleFraction = info.visibleFraction;
    final wasVisible = _isScreenVisible;
    _isScreenVisible = visibleFraction > 0.1;

    if (kDebugMode) {
      print('DEBUG: Screen visibility changed - visibleFraction: $visibleFraction, isScreenVisible: $_isScreenVisible');
    }

    if (wasVisible != _isScreenVisible) {
      if (_isScreenVisible && _isAppInForeground) {
        _updateVideoPlayback();
      } else {
        _pauseAllVideos();
      }
    }
  }

  Future<VideoPlayerController> _getController(String videoUrl) async {
    if (kDebugMode) {
      print('DEBUG: Attempting to load video URL: $videoUrl');
    }
    if (_controllers.containsKey(videoUrl)) {
      return _controllers[videoUrl]!;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      await controller.initialize().then((_) {
        if (kDebugMode) {
          print('DEBUG: Video initialized successfully');
        }
        if (mounted) {
          controller.setVolume(1.0);
        }
      }).catchError((error) {
        if (kDebugMode) {
          print('Error initializing video: $error');
        }
        throw error;
      });

      controller.setLooping(false);
      _controllers[videoUrl] = controller;
      return controller;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading video for URL $videoUrl: $e');
      }
      final errorController = VideoPlayerController.networkUrl(Uri.parse('data:text/plain,'));
      await errorController.initialize();
      return errorController;
    }
  }

  void _onPageScroll(List<MockQueryDocumentSnapshot> posts) {
    final currentPage = _pageController.page?.round() ?? 0;

    _controllers.forEach((videoUrl, controller) {
      if (controller.value.isInitialized && !controller.value.hasError) {
        final videoIndex = posts.indexWhere((post) => post.data()['videoUrl'] == videoUrl);

        if (videoIndex == currentPage && _isScreenVisible && _isAppInForeground) {
          if (!controller.value.isPlaying && controller.value.isInitialized) {
            controller.play().catchError((e) {
              if (kDebugMode) {
                print('Error playing video on page change: $e');
              }
            });
          }
        } else {
          if (controller.value.isPlaying) {
            controller.pause();
          }
        }
      }
    });
  }

  void _handleVideoReady(String videoUrl, VideoPlayerController controller, List<MockQueryDocumentSnapshot> posts) {
    final videoIndex = posts.indexWhere((post) => post.data()['videoUrl'] == videoUrl);

    if (videoIndex != -1) {
      final currentPage = _pageController.page?.round() ?? 0;
      // Only auto-play if screen is visible, app is in foreground, and video is the current page
      if (videoIndex == currentPage && _isScreenVisible && _isAppInForeground && !controller.value.isPlaying && controller.value.isInitialized && !controller.value.hasError) {
        controller.play().catchError((e) {
          if (kDebugMode) {
            print('Error auto-playing video: $e');
          }
        });
      } else if (controller.value.isPlaying && (videoIndex != currentPage || !_isScreenVisible || !_isAppInForeground)) {
        // Pause video if it's not the current page or screen is not visible
        controller.pause();
      }
    }
  }

  Future<void> _addComment(String postId, String commentText) async {
    if (commentText.trim().isEmpty) return;

    try {
      await _postService.addComment(postId, commentText);
      setState(() {
        _commentCounts[postId] = (_commentCounts[postId] ?? 0) + 1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')),
        );
      }
    }
  }

  Future<void> _shareVideo(String description, String videoUrl, String displayName, String postId) async {
    try {
      final shareText = description.isNotEmpty
          ? 'Check out this video: "$description" by $displayName\n\n$videoUrl'
          : 'Check out this video by $displayName\n\n$videoUrl';

      await Share.share(
        shareText,
        subject: 'Shared from Church App',
      );

      await _postService.sharePost(postId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video shared successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing video: $e')),
        );
      }
    }
  }

  void _showCommentDialog(String postId) {
    final commentController = TextEditingController();
    bool showEmojiPicker = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_commentCounts[postId] ?? 0} Comments',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<MockQuerySnapshot>(
                  stream: _postService.getPostComments(postId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final comments = snapshot.data?.docs ?? [];

                    if (comments.isEmpty) {
                      return const Center(
                        child: Text(
                          'No comments yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final data = comment.data();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey,
                                child: Icon(Icons.person, size: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'User',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['comment'] ?? '',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTimestamp(data['timestamp']),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: commentController,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                            color: const Color(0xFF1E3A8A),
                          ),
                          onPressed: () {
                            setState(() {
                              showEmojiPicker = !showEmojiPicker;
                            });
                          },
                          tooltip: 'Add emoji',
                        ),
                      ),
                      maxLines: 3,
                    ),
                    if (showEmojiPicker)
                      SizedBox(
                        height: 250,
                        child: EmojiPicker(
                          onEmojiSelected: (category, emoji) {
                            final text = commentController.text;
                            final selection = commentController.selection;
                            final newText = text.replaceRange(
                              selection.start,
                              selection.end,
                              emoji.emoji,
                            );
                            commentController.value = TextEditingValue(
                              text: newText,
                              selection: TextSelection.collapsed(
                                offset: selection.start + emoji.emoji.length,
                              ),
                            );
                          },
                          config: const Config(),
                        ),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: commentController.text.trim().isNotEmpty
                          ? () {
                              _addComment(postId, commentController.text);
                              commentController.clear();
                            }
                          : null,
                      child: const Text('Post Comment'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = timestamp is Timestamp ? timestamp.toDate() : DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: TikTokFeedScreen building');
    return StreamBuilder<MockQuerySnapshot>(
      stream: _postService.getContentVideos(),
      builder: (context, snapshot) {
        print('DEBUG: TikTokFeedScreen stream builder - connectionState: ${snapshot.connectionState}, hasError: ${snapshot.hasError}, hasData: ${snapshot.hasData}');
        if (snapshot.hasError) {
          print('DEBUG: TikTokFeedScreen error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('DEBUG: TikTokFeedScreen waiting for data');
          return const Center(child: CircularProgressIndicator());
        }

        List<MockQueryDocumentSnapshot> filteredPosts = snapshot.data?.docs ?? [];
        print('DEBUG: TikTokFeedScreen posts count: ${filteredPosts.length}');

        final posts = filteredPosts;

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.video_library,
                  size: 80,
                  color: Color(0xFF1E3A8A),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No videos available',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Christian videos will appear here when available',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  '🙏 📖 ⛪ 🎵 💒',
                  style: TextStyle(
                    fontSize: 24,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return VisibilityDetector(
          key: const Key('tiktok_feed_screen'),
          onVisibilityChanged: _onVisibilityChanged,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                _onPageScroll(posts);
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: (index) {
                _onPageScroll(posts);
              },
              itemCount: posts.length + 1,
              itemBuilder: (context, index) {
                if (index == posts.length) {
                  return Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.video_library,
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "You've reached the end!",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Post your videos and share your faith with the community",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CreatePostScreen(source: 'tiktok')),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create Video Post'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final post = posts[index];
                final data = post.data();
                final videoUrl = data['videoUrl'] as String?;
                final postId = post.id;
                final description = data['content'] ?? '';
                final username = data['userName'] ?? data['name'] ?? '';
                final fullName = data['full_name'] ?? '';
                final displayName = (fullName.isNotEmpty ? fullName : (username.isNotEmpty ? username : 'Anonymous User')).replaceAll('@', '');
                final profilePicUrl = data['profilePictureUrl'] ?? '';
                final userId = data['user_id'] as String?;
                final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                final isOwner = userId == currentUserId;

                print('DEBUG: Video post data - username: $username, profilePicUrl: $profilePicUrl, userId: $userId, isOwner: $isOwner');

                if (userId != null && !_followingStatus.containsKey(userId)) {
                  _userService.isFollowing(userId).then((isFollowing) {
                    if (mounted) {
                      setState(() {
                        _followingStatus[userId] = isFollowing;
                      });
                    }
                  });
                }

                final isFollowing = _followingStatus[userId] ?? false;
                final commentCount = (data['comments'] as List?)?.length ?? 0;

                if (!_commentCounts.containsKey(postId)) {
                  _commentCounts[postId] = commentCount;
                }

                if (videoUrl == null || videoUrl.isEmpty) {
                  if (kDebugMode) {
                    print('DEBUG: Empty or null video URL for post $postId');
                  }
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: Text(
                        'Video not available',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }

                final uri = Uri.parse(videoUrl);
                final path = uri.path.toLowerCase();
                final isVideoFile = path.endsWith('.mp4') ||
                                    path.endsWith('.mov') ||
                                    path.endsWith('.avi') ||
                                    path.endsWith('.mkv') ||
                                    path.endsWith('.webm') ||
                                    path.endsWith('.m4v');

                if (kDebugMode) {
                  print('DEBUG: Validating video URL: $videoUrl');
                  print('DEBUG: Path: $path, isVideoFile: $isVideoFile');
                }

                if (!isVideoFile) {
                  if (kDebugMode) {
                    print('DEBUG: Non-video file detected, showing image message for: $videoUrl');
                  }
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image,
                            color: Colors.white,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'This post contains an image, not a video',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (kDebugMode) {
                  print('DEBUG: Video file validated, proceeding with: $videoUrl');
                }

                return FutureBuilder<VideoPlayerController>(
                  future: _getController(videoUrl),
                  builder: (context, controllerSnapshot) {
                    if (controllerSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (controllerSnapshot.hasError) {
                      if (kDebugMode) {
                        print('FutureBuilder error for video $videoUrl: ${controllerSnapshot.error}');
                      }
                      return Container(
                        color: Colors.black,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                controllerSnapshot.error.toString().contains('MEDIA_ERR_SRC_NOT_SUPPORTED')
                                    ? 'Video codec not supported'
                                    : 'Error loading video',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'This video is not encoded in a web-compatible format.\nPlease ensure videos use H.264 video codec with AAC audio.',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final controller = controllerSnapshot.data!;
                    if (!controller.value.isInitialized) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _handleVideoReady(videoUrl, controller, posts);
                    });

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final screenHeight = MediaQuery.of(context).size.height;

                        final isSmallScreen = screenWidth < 400;
                        final isMediumScreen = screenWidth < 600;

                        final actionButtonSize = isSmallScreen ? 28.0 : 32.0;
                        final actionIconSize = isSmallScreen ? 24.0 : 28.0;
                        final textFontSize = isSmallScreen ? 10.0 : 12.0;
                        final nameFontSize = isSmallScreen ? 14.0 : 16.0;
                        final descFontSize = isSmallScreen ? 12.0 : 14.0;

                        final rightMargin = isSmallScreen ? 8.0 : 16.0;
                        final bottomMargin = isSmallScreen ? 60.0 : 80.0;
                        final leftMargin = isSmallScreen ? 8.0 : 16.0;
                        final bottomTextMargin = isSmallScreen ? 80.0 : 100.0;
                        final rightTextMargin = isSmallScreen ? 60.0 : 80.0;
                        final followButtonBottom = isSmallScreen ? 20.0 : 40.0;

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (controller.value.isPlaying) {
                                  controller.pause();
                                } else {
                                  if (controller.value.position >= controller.value.duration) {
                                    controller.seekTo(Duration.zero);
                                  }
                                  controller.play();
                                }
                                setState(() {});
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: controller.value.size.width,
                                      height: controller.value.size.height,
                                      child: VideoPlayer(controller),
                                    ),
                                  ),
                                  if (!controller.value.isPlaying && !controller.value.isBuffering)
                                    Center(
                                      child: Container(
                                        color: Colors.black26,
                                        child: Icon(
                                          Icons.play_circle_fill,
                                          size: isSmallScreen ? 48 : 64,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Positioned(
                              right: rightMargin,
                              bottom: bottomMargin,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    iconSize: actionButtonSize,
                                    icon: Icon(
                                      _liked.contains(postId)
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border,
                                      color: _liked.contains(postId)
                                          ? Colors.red
                                          : Colors.white,
                                    ),
                                    onPressed: () async {
                                      try {
                                        await _communityService.toggleLike(postId);
                                        setState(() {
                                          if (_liked.contains(postId)) {
                                            _liked.remove(postId);
                                          } else {
                                            _liked.add(postId);
                                          }
                                        });
                                      } catch (e) {
                                        print('Error toggling like: $e');
                                      }
                                    },
                                  ),
                                  SizedBox(height: isSmallScreen ? 12 : 16),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        (_commentCounts[postId] ?? 0).toString(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: textFontSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        iconSize: actionButtonSize,
                                        icon: const Icon(Icons.message, color: Colors.white),
                                        onPressed: () => _showCommentDialog(postId),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isSmallScreen ? 12 : 16),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        (data['shares'] as int?)?.toString() ?? '0',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: textFontSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        iconSize: actionButtonSize,
                                        icon: const Icon(Icons.share, color: Colors.white),
                                        onPressed: () => _shareVideo(description, videoUrl, displayName, postId),
                                      ),
                                    ],
                                  ),
                                  if (isOwner) SizedBox(height: isSmallScreen ? 12 : 16),
                                  if (isOwner) IconButton(
                                    iconSize: actionButtonSize,
                                    icon: const Icon(Icons.delete, color: Colors.white),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('Delete Post'),
                                          content: Text('Are you sure you want to delete this post?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        try {
                                          await _postService.deletePost(postId);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Post deleted successfully')),
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
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: leftMargin,
                              bottom: bottomTextMargin,
                              right: rightTextMargin,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      final userId = data['user_id'] as String?;
                                      if (userId != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ProfileScreen(userId: userId),
                                          ),
                                        );
                                      }
                                    },
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: isSmallScreen ? 16 : 20,
                                          backgroundImage: profilePicUrl.isNotEmpty
                                              ? NetworkImage(profilePicUrl)
                                              : null,
                                          backgroundColor: const Color(0xFF1E3A8A),
                                          child: profilePicUrl.isEmpty
                                              ? Text(
                                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: isSmallScreen ? 12 : 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          displayName,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: nameFontSize,
                                            shadows: const [
                                              Shadow(
                                                blurRadius: 4,
                                                color: Colors.black,
                                                offset: Offset(1, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 4 : 8),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: descFontSize,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 4,
                                          color: Colors.black,
                                          offset: Offset(1, 1),
                                        ),
                                      ],
                                    ),
                                    maxLines: isSmallScreen ? 1 : 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: leftMargin,
                              bottom: followButtonBottom,
                              child: ElevatedButton(
                                onPressed: userId == null
                                    ? null
                                    : () async {
                                        try {
                                          if (isFollowing) {
                                            await _userService.unfollowUser(userId);
                                            setState(() {
                                              _followingStatus[userId] = false;
                                            });
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Unfollowed $displayName')),
                                              );
                                            }
                                          } else {
                                            await _userService.followUser(userId);
                                            setState(() {
                                              _followingStatus[userId] = true;
                                            });
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Followed $displayName')),
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Error: $e')),
                                            );
                                          }
                                        }
                                      },
                                child: Text(
                                  isFollowing ? 'Following' : 'Follow',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowing ? Colors.grey : Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 12 : 16,
                                    vertical: isSmallScreen ? 6 : 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}