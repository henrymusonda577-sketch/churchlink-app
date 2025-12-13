import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/user_service.dart';
import 'services/post_service.dart';
import 'services/badge_service.dart';
import 'services/bible_service.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'bookmarks_screen.dart';
import 'notes_screen.dart';
import 'login_screen.dart';
import 'widgets/badge_display.dart';
import 'story_viewer_screen.dart';

class FacebookProfileScreen extends StatefulWidget {
  final Map<String, String> userInfo;

  const FacebookProfileScreen({super.key, required this.userInfo});

  @override
  State<FacebookProfileScreen> createState() => FacebookProfileScreenState();
}

class FacebookProfileScreenState extends State<FacebookProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserService _userService = UserService();
  final PostService _postService = PostService();
  final BadgeService _badgeService = BadgeService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic> _userBadges = {};
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  Map<String, int> _userStats = {'posts': 0, 'followers': 0, 'following': 0};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserBadges();
    _loadFollowStatus();
    _loadUserStats();
  }

  Future<void> _loadFollowStatus() async {
    if (widget.userInfo['uid'] != null &&
        widget.userInfo['uid'] != _auth.currentUser?.uid) {
      try {
        final isFollowing =
            await _userService.isFollowing(widget.userInfo['uid']!);
        setState(() {
          _isFollowing = isFollowing;
        });
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _loadUserBadges() async {
    final badges = await _badgeService.getUserBadges();
    setState(() {
      _userBadges = badges;
    });
  }

  Future<void> _loadUserStats() async {
    final userId = widget.userInfo['uid'] ?? widget.userInfo['id'];
    if (userId != null) {
      final stats = await _userService.getUserStats(userId);
      setState(() {
        _userStats = stats;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildCoverPhoto(),
            _buildProfileInfo(),
            _buildActionButtons(),
            _buildTabBar(),
            SizedBox(
              height: MediaQuery.of(context).size.height *
                  2, // Give enough space for content
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPostsTab(),
                  _buildStoriesTab(),
                  _buildAboutTab(),
                ],
              ),
            ),
            if (widget.userInfo['uid'] == _auth.currentUser?.uid)
              _buildOwnerActions(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      title: const Text('Profile'),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _navigateToEditProfile(),
        ),
      ],
    );
  }

  Widget _buildCoverPhoto() {
    return Stack(
      children: [
        // Cover photo
        Container(
          height: 200,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1E3A8A),
                Color(0xFF3B82F6),
              ],
            ),
          ),
        ),
        // Edit cover button
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.camera_alt,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        // Settings three dots button
        Positioned(
          top: 16,
          right: 70,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        SettingsScreen(userInfo: widget.userInfo),
                  ),
                );
              },
              child: const Icon(
                Icons.more_vert,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        // Profile picture overlapping cover photo
        Positioned(
          left: 16,
          bottom: 0,
          child: Stack(
            children: [
              // Profile picture
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 4,
                  ),
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      widget.userInfo['profilePictureUrl'] != null &&
                              widget.userInfo['profilePictureUrl']!.isNotEmpty
                          ? NetworkImage(widget.userInfo['profilePictureUrl']!)
                          : null,
                  child: widget.userInfo['profilePictureUrl'] == null ||
                          widget.userInfo['profilePictureUrl']!.isEmpty
                      ? Text(
                          _getAvatarLetter(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 40,
                            color: Colors.grey,
                          ),
                        )
                      : null,
                  onBackgroundImageError: (exception, stackTrace) {
                    print('Error loading profile picture: $exception');
                  },
                ),
              ),
              // Edit profile picture button
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A8A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfo() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User name
          Text(
            widget.userInfo['name'] ?? 'User',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // User role
          Text(
            widget.userInfo['role'] ?? 'Member',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn('Posts', _userStats['posts'] ?? 0),
              _buildStatColumn('Followers', _userStats['followers'] ?? 0),
              _buildStatColumn('Following', _userStats['following'] ?? 0),
            ],
          ),

          const SizedBox(height: 16),

          // Bio section
          if (widget.userInfo['bio']?.isNotEmpty == true)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                widget.userInfo['bio']!,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),

          // Donation Badges
          if (_userBadges['badges'] != null &&
              (_userBadges['badges'] as List).isNotEmpty)
            BadgeDisplay(badges: List<String>.from(_userBadges['badges'])),
          // Church information
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Position in Church
                if (widget.userInfo['positionInChurch']?.isNotEmpty == true)
                  Row(
                    children: [
                      const Icon(Icons.work,
                          size: 20, color: Color(0xFF1E3A8A)),
                      const SizedBox(width: 8),
                      Text(
                        widget.userInfo['positionInChurch']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                // Church Name
                if (widget.userInfo['churchName']?.isNotEmpty == true)
                  Row(
                    children: [
                      const Icon(Icons.church,
                          size: 20, color: Color(0xFF1E3A8A)),
                      const SizedBox(width: 8),
                      Text(
                        widget.userInfo['churchName']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                // Relationship Status
                if (widget.userInfo['relationshipStatus']?.isNotEmpty == true)
                  Row(
                    children: [
                      const Icon(Icons.favorite, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        widget.userInfo['relationshipStatus']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Follow/Following button (for other users)
          if (widget.userInfo['uid'] != null &&
              widget.userInfo['uid'] != _auth.currentUser?.uid)
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoadingFollow ? null : _handleFollowToggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isFollowing ? Colors.grey : const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isLoadingFollow
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _isFollowing ? 'Following' : 'Follow',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

          // Message button (for other users)
          if (widget.userInfo['uid'] != null &&
              widget.userInfo['uid'] != _auth.currentUser?.uid)
            const SizedBox(width: 12),

          if (widget.userInfo['uid'] != null &&
              widget.userInfo['uid'] != _auth.currentUser?.uid)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  // TODO: Navigate to message screen
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1E3A8A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Message',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ),

          // Edit Profile button (for own profile)
          if (widget.userInfo['uid'] == _auth.currentUser?.uid)
            Expanded(
              child: ElevatedButton(
                onPressed: () => _navigateToEditProfile(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF1E3A8A),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF1E3A8A),
        indicatorWeight: 3,
        tabs: const [
          Tab(
            child: Text(
              'Posts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Tab(
            child: Text(
              'Stories',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Tab(
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    final userId = widget.userInfo['uid'];
    if (userId == null) {
      return const Center(child: Text('User ID not available'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _postService.getUserPosts(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading posts'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No posts yet. Start sharing your thoughts!',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final postData = post.data() as Map<String, dynamic>;

            return _buildPostCard(post.id, postData);
          },
        );
      },
    );
  }

  Widget _buildStoriesTab() {
    final userId = widget.userInfo['uid'];
    if (userId == null) {
      return const Center(child: Text('User ID not available'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _postService.getUserStories(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading stories'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stories = snapshot.data!.docs;

        if (stories.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No stories yet. Share your daily moments!',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: stories.length,
          itemBuilder: (context, index) {
            final story = stories[index];
            final storyData = story.data() as Map<String, dynamic>;

            return _buildStoryCard(storyData);
          },
        );
      },
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAboutCard(
            'Personal Information',
            [
              _buildInfoRow('Name', widget.userInfo['name'] ?? 'Not provided'),
              _buildInfoRow('Role', widget.userInfo['role'] ?? 'Not provided'),
              _buildInfoRow(
                  'Email', widget.userInfo['email'] ?? 'Not provided'),
              _buildInfoRow(
                  'Phone', widget.userInfo['phone'] ?? 'Not provided'),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.userInfo['bio']?.isNotEmpty == true)
            _buildAboutCard(
              'Bio',
              [
                _buildInfoRow('About', widget.userInfo['bio']!),
              ],
            ),
          const SizedBox(height: 16),
          _buildAboutCard(
            'Church Information',
            [
              _buildInfoRow('Position',
                  widget.userInfo['positionInChurch'] ?? 'Not specified'),
              _buildInfoRow(
                  'Church', widget.userInfo['churchName'] ?? 'Not specified'),
            ],
          ),
          const SizedBox(height: 16),
          _buildAboutCard(
            'Account Information',
            [
              _buildInfoRow(
                  'Member since', _formatDate(widget.userInfo['createdAt'])),
              _buildInfoRow(
                  'Last login', _formatDate(widget.userInfo['lastLogin'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(String postId, Map<String, dynamic> postData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post content
              if (postData['content']?.isNotEmpty == true)
                Text(
                  postData['content'],
                  style: const TextStyle(fontSize: 16),
                ),

              // Post media
              if (postData['imageUrl'] != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      postData['imageUrl']!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              if (postData['videoUrl'] != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        color: Colors.black,
                        child: const Center(
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Post stats
              Row(
                children: [
                  Icon(Icons.favorite, color: Colors.red, size: 16),
                  const SizedBox(width: 4),
                  Text('${postData['likes'] ?? 0}'),
                  const SizedBox(width: 16),
                  Icon(Icons.comment, color: Colors.grey, size: 16),
                  const SizedBox(width: 4),
                  Text('${postData['comments'] ?? 0}'),
                  const SizedBox(width: 16),
                  Icon(Icons.share, color: Colors.grey, size: 16),
                  const SizedBox(width: 4),
                  Text('${postData['shares'] ?? 0}'),
                  const Spacer(),
                  Text(
                    _formatTimestamp(postData['timestamp']),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryCard(Map<String, dynamic> storyData) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          // Get all stories for the viewer
          final allStories = await _postService.getStories().first;
          final storyDocs = allStories.docs;

          // Find the index of this story in the full list
          final currentIndex =
              storyDocs.indexWhere((doc) => doc.id == storyData['postId']);

          if (currentIndex >= 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StoryViewerScreen(
                  stories: storyDocs
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .toList(),
                  initialIndex: currentIndex,
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: storyData['imageUrl'] != null
                ? DecorationImage(
                    image: NetworkImage(storyData['imageUrl']!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTimestamp(storyData['timestamp']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Not available';

    try {
      final dateTime = DateTime.parse(dateString);
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    } catch (e) {
      return 'Not available';
    }
  }

  Future<void> _handleFollowToggle() async {
    if (widget.userInfo['uid'] == null) return;

    setState(() {
      _isLoadingFollow = true;
    });

    try {
      if (_isFollowing) {
        await _userService.unfollowUser(widget.userInfo['uid']!);
        setState(() {
          _isFollowing = false;
        });
      } else {
        await _userService.followUser(widget.userInfo['uid']!);
        setState(() {
          _isFollowing = true;
        });
      }
    } catch (e) {
      // Handle error silently or show a snackbar
      print('Error toggling follow status: $e');
    } finally {
      setState(() {
        _isLoadingFollow = false;
      });
    }
  }

  void _navigateToEditProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(userInfo: widget.userInfo),
      ),
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getAvatarLetter() {
    final name = widget.userInfo['name'];
    if (name != null && name.isNotEmpty && name.trim().isNotEmpty) {
      final firstChar = name.trim()[0].toUpperCase();
      // Avoid showing 'U' if the first letter happens to be 'U'
      return firstChar != 'U'
          ? firstChar
          : (name.length > 1 ? name[1].toUpperCase() : 'A');
    }
    return 'A'; // Default fallback
  }

  Widget _buildOwnerActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.bookmark, color: Color(0xFF1E3A8A)),
              title: const Text('Bible Bookmarks'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookmarksScreen(bibleService: BibleService()),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.note, color: Color(0xFF1E3A8A)),
              title: const Text('Bible Notes'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotesScreen(bibleService: BibleService()),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Color(0xFF1E3A8A)),
              title: const Text('Settings'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(userInfo: const {}),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Color(0xFF1E3A8A)),
              title: const Text('Prayer History'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prayer history coming soon!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help, color: Color(0xFF1E3A8A)),
              title: const Text('Help & Support'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Help & support coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            await _auth.signOut();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text('Sign Out'),
        ),
      ),
    );
  }
}
  }
}
