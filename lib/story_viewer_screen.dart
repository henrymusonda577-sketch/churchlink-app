import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/feed_video_player.dart';
import 'widgets/safe_network_image.dart';

class StoryViewerScreen extends StatefulWidget {
  final String? imageUrl;
  final String? videoUrl;
  final String? content;
  final String? authorName;
  final Timestamp? timestamp;
  final List<Map<String, dynamic>>? stories;
  final int? initialIndex;

  const StoryViewerScreen({
    super.key,
    this.imageUrl,
    this.videoUrl,
    this.content,
    this.authorName,
    this.timestamp,
    this.stories,
    this.initialIndex,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  int _currentIndex = 0;
  static const Duration _storyDuration = Duration(seconds: 5);
  late final List<Map<String, dynamic>> _stories;
  late final bool _isMulti;
  late final Ticker _ticker;
  double _progress = 0.0;
  DateTime? _lastStart;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _isMulti = (widget.stories != null && widget.stories!.isNotEmpty);
    _stories = _isMulti
        ? widget.stories!
        : [
            {
              'imageUrl': widget.imageUrl,
              'videoUrl': widget.videoUrl,
              'content': widget.content,
              'authorName': widget.authorName,
              'timestamp': widget.timestamp,
            },
          ];
    _currentIndex = (widget.initialIndex ?? 0).clamp(0, _stories.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _startProgress();
    // Record view for initial story after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordView();
    });
  }

  void _startProgress() {
    _progress = 0.0;
    _elapsed = Duration.zero;
    _lastStart = DateTime.now();
    _ticker = Ticker((_) {
      if (!mounted || _lastStart == null) return;
      final total = DateTime.now().difference(_lastStart!) + _elapsed;
      final p = (total.inMilliseconds / _storyDuration.inMilliseconds)
          .clamp(0.0, 1.0);
      setState(() => _progress = p.toDouble());
      if (p >= 1.0) {
        _advance();
      }
    });
    _ticker.start();
  }

  void _advance() {
    if (_currentIndex < _stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _goBack() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      setState(() {
        _elapsed = Duration.zero;
        _lastStart = DateTime.now();
        _progress = 0.0;
      });
    }
  }

  void _pause() {
    if (_ticker.isActive && _lastStart != null) {
      _elapsed += DateTime.now().difference(_lastStart!);
      _lastStart = null;
      _ticker.stop();
    }
  }

  void _resume() {
    if (!_ticker.isActive) {
      _lastStart = DateTime.now();
      _ticker.start();
    }
  }

  Future<void> _recordView() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final storyId = _stories[_currentIndex]['id'];

    print('DEBUG: _recordView called - currentUserId: $currentUserId, storyId: $storyId');

    if (currentUserId == null || storyId == null) {
      print('DEBUG: _recordView failed - missing userId or storyId');
      return;
    }

    try {
      print('DEBUG: Attempting to record story view for story $storyId by user $currentUserId');

      // Insert view record, ignore if already exists due to UNIQUE constraint
      final response = await Supabase.instance.client
          .from('story_views')
          .upsert({
            'story_id': storyId,
            'user_id': currentUserId,
          });

      print('DEBUG: Story view recorded successfully. Response: $response');

      // Verify the view was recorded by fetching it back
      final verifyResponse = await Supabase.instance.client
          .from('story_views')
          .select('id, story_id, user_id, created_at')
          .eq('story_id', storyId)
          .eq('user_id', currentUserId)
          .single();

      print('DEBUG: Verification - view record exists: $verifyResponse');

    } catch (e) {
      // Silently fail if view recording fails
      print('DEBUG: Failed to record story view: $e');
      print('DEBUG: Stack trace: ${StackTrace.current}');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchViewers() async {
    final storyId = _stories[_currentIndex]['id'];
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    print('DEBUG: _fetchViewers called - storyId: $storyId, currentUserId: $currentUserId');

    if (storyId == null) {
      print('DEBUG: _fetchViewers failed - storyId is null');
      return [];
    }

    try {
      print('DEBUG: Fetching viewers for story $storyId');

      final response = await Supabase.instance.client
          .from('story_views')
          .select('user_id, created_at, public.users!inner(name, profile_picture)')
          .eq('story_id', storyId)
          .order('created_at', ascending: false);

      print('DEBUG: Raw response from story_views query: $response');
      print('DEBUG: Number of viewers found: ${response.length}');

      final viewers = List<Map<String, dynamic>>.from(response);
      print('DEBUG: Processed viewers list: $viewers');

      return viewers;
    } catch (e) {
      print('DEBUG: Failed to fetch story viewers: $e');
      print('DEBUG: Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  void _showViewersDialog() async {
    final viewers = await _fetchViewers();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Story Viewers',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (viewers.isEmpty)
                const Text(
                  'No viewers yet',
                  style: TextStyle(color: Colors.white70),
                )
              else
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: viewers.length,
                    itemBuilder: (context, index) {
                      final viewer = viewers[index];
                      final user = viewer['users'] as Map<String, dynamic>?;
                      final name = user?['name'] as String? ?? 'Unknown';
                      final profilePicture = user?['profile_picture'] as String?;
                      final viewedAt = viewer['created_at'] as String?;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profilePicture != null
                              ? NetworkImage(profilePicture)
                              : null,
                          child: profilePicture == null
                              ? Text(name[0].toUpperCase())
                              : null,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          _formatTimestamp(viewedAt),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteStory() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final storyUserId = _stories[_currentIndex]['userId'];

    if (currentUserId == null || currentUserId != storyUserId) {
      return;
    }

    try {
      // Delete from Supabase stories table
      await Supabase.instance.client
          .from('stories')
          .delete()
          .eq('id', _stories[_currentIndex]['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story deleted successfully')),
        );

        // If this was the last story, go back
        if (_stories.length == 1) {
          Navigator.of(context).pop();
        } else {
          // Remove the story from the list and update UI
          setState(() {
            _stories.removeAt(_currentIndex);
            if (_currentIndex >= _stories.length) {
              _currentIndex = _stories.length - 1;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete story: $e')),
        );
      }
    }
  }

  bool _isCurrentUserOwner() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final storyUserId = _stories[_currentIndex]['userId'];
    return currentUserId != null && currentUserId == storyUserId;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _formatTimestamp(dynamic ts) {
    DateTime? t;
    if (ts is Timestamp) {
      t = ts.toDate();
    } else if (ts is String) {
      t = DateTime.parse(ts);
    } else if (ts is DateTime) {
      t = ts;
    } else {
      return '';
    }

    final now = DateTime.now();
    final d = now.difference(t);
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    if (d.inMinutes > 0) return '${d.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final width = MediaQuery.of(context).size.width;
                  final dx = details.localPosition.dx;
                  if (dx < width * 0.33) {
                    _goBack();
                  } else {
                    _advance();
                  }
                },
                onLongPressStart: (_) => _pause(),
                onLongPressEnd: (_) => _resume(),
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) {
                    setState(() {
                      _currentIndex = i;
                    });
                    _recordView();
                    _ticker.stop();
                    _elapsed = Duration.zero;
                    _lastStart = DateTime.now();
                    _ticker.start();
                  },
                  itemCount: _stories.length,
                  itemBuilder: (context, index) {
                    final story = _stories[index];
                    final String? videoUrl = story['videoUrl'] as String?;
                    final String? imageUrl = story['imageUrl'] as String?;
                    final String? content = story['content'] as String?;

                    if (videoUrl != null && videoUrl.startsWith('http')) {
                      return FeedVideoPlayer(
                        videoUrl: videoUrl,
                        aspectRatio: MediaQuery.of(context).size.aspectRatio,
                      );
                    } else if (imageUrl != null &&
                        imageUrl.startsWith('http')) {
                      return SafeNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        errorWidget: const Center(
                          child: Icon(Icons.broken_image,
                              color: Colors.white70, size: 64),
                        ),
                      );
                    } else if (content != null && content.isNotEmpty) {
                      return Container(
                        color: Colors.black,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              content,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    } else {
                      return const Center(
                        child: Icon(Icons.image_not_supported,
                            color: Colors.white70, size: 64),
                      );
                    }
                  },
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Column(
                children: [
                  // progress bar row
                  Row(
                    children: List.generate(_stories.length, (i) {
                      final isActive = i == _currentIndex;
                      final value = isActive
                          ? _progress
                          : i < _currentIndex
                              ? 1.0
                              : 0.0;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: value,
                              child: Container(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      if (_isCurrentUserOwner()) ...[
                        IconButton(
                          icon: const Icon(Icons.visibility, color: Colors.white),
                          onPressed: _showViewersDialog,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: _deleteStory,
                        ),
                      ],
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: (_stories[_currentIndex]['authorProfilePicture'] as String?) != null
                            ? NetworkImage(_stories[_currentIndex]['authorProfilePicture'] as String)
                            : null,
                        child: (_stories[_currentIndex]['authorProfilePicture'] as String?) == null
                            ? Text(
                                ((_stories[_currentIndex]['authorName'] as String?) ?? 'S')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_stories[_currentIndex]['authorName']
                                      as String?) ??
                                  'Story',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatTimestamp(_stories[_currentIndex]
                                  ['timestamp']),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
