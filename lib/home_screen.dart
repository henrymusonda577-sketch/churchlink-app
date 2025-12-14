import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'bible_screen.dart';
import 'chat_screen.dart';
import 'create_post_screen.dart';
import 'supabase_test_screen.dart';
import 'facebook_profile_screen.dart';
import 'church_discovery.dart';
import 'discover_people_screen.dart';
import 'services/user_service.dart';
import 'services/community_service.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, String> userInfo;

  const HomeScreen({super.key, required this.userInfo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  final CommunityService _communityService = CommunityService();
  Stream<List<Map<String, dynamic>>>? _postsStream;
  Map<String, Map<String, dynamic>> _userProfiles = {};

  @override
  void initState() {
    super.initState();
    _initializePosts();
  }

  void _initializePosts() {
    _postsStream = _communityService.getTextPosts();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        title: const Text('Church-Link',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
            tooltip: 'Admin Panel - Delete Users',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SupabaseTestScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.people, color: Colors.white),
            onPressed: () {
              print('DEBUG: People icon pressed, navigating to DiscoverPeopleScreen');
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => DiscoverPeopleScreen(userInfo: widget.userInfo)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Download Church-Link',
            onPressed: () async {
              await launchUrl(Uri.parse('/download.html'));
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _selectedIndex = index),
        children: [
          _buildHomeTab(),
          const BibleScreen(),
          const ChatScreen(),
          ChurchDiscovery(userInfo: widget.userInfo),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          _pageController.animateToPage(index,
              duration: const Duration(milliseconds: 300), curve: Curves.ease);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Bible'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.church), label: 'Church'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SupabaseTestScreen())),
                backgroundColor: Colors.red,
                tooltip: 'Delete Users - Admin Panel',
                child: const Icon(Icons.delete_forever, color: Colors.white),
              ),
              const SizedBox(height: 16),
              FloatingActionButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CreatePostScreen(source: 'home'))),
                backgroundColor: const Color(0xFF1E3A8A),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          )
          : null,
    );
  }

  Widget _buildHomeTab() {
    return Column(
      children: [
        _buildVerseOfDay(),
        Expanded(child: _buildPostsFeed()),
      ],
    );
  }

  Widget _buildVerseOfDay() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.book, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text('Verse of the Day',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 16),
          Text(
            '"For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life."',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic),
          ),
          SizedBox(height: 8),
          Text('John 3:16',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPostsFeed() {
    return StreamBuilder<List<Map<String, dynamic>>>(
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
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Error loading posts',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() => _initializePosts()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.post_add, size: 64, color: Color(0xFF1E3A8A)),
                const SizedBox(height: 16),
                const Text('No posts yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Be the first to share with the community!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CreatePostScreen(source: 'home')),
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
              if (postId == null) return const SizedBox.shrink();

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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              likes.contains(userId)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color:
                                  likes.contains(userId) ? Colors.red : null,
                            ),
                            onPressed: postId != null ? () => _toggleLike(postId) : null,
                          ),
                          Text('${likes.length}'),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.comment_outlined),
                            onPressed: () {},
                          ),
                          Text('${comments.length}'),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () {},
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
    );
  }

  Future<void> _toggleLike(String postId) async {
    try {
      await _communityService.toggleLike(postId);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling like: $e')),
        );
      }
    }
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

}
