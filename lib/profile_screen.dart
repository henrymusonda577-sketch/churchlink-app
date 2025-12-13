import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'bookmarks_screen.dart';
import 'notes_screen.dart';
import 'services/bible_service.dart';
import 'services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // If null, shows current user's profile
  final bool showFullProfile; // If true, shows full profile with editing options

  const ProfileScreen({
    super.key,
    this.userId,
    this.showFullProfile = true, // Default to full profile for backward compatibility
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  final UserService _userService = UserService();
  Map<String, int> _userStats = {'posts': 0, 'followers': 0, 'following': 0};
  List<Map<String, dynamic>> _userPosts = [];
  bool _isLoadingStats = false;
  bool _isLoadingPosts = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when coming back to this screen
    print('DEBUG ProfileScreen.didChangeDependencies: Refreshing user profile');
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      Map<String, dynamic>? userProfile;
      if (widget.userId != null) {
        // Load specific user's profile
        userProfile = await _userService.getUserById(widget.userId!);
      } else {
        // Load current user's profile
        userProfile = await _userService.getUserInfo();
      }

      print('DEBUG ProfileScreen._loadUserProfile: Loaded user profile: ${userProfile?['name']}, profile_picture_url: ${userProfile?['profile_picture_url']}');

      setState(() {
        _userProfile = userProfile;
        _isLoading = false;
      });

      // Load additional data for the profile
      if (_userProfile != null) {
        await _loadUserStats();
        await _loadUserPosts();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserStats() async {
    if (_userProfile == null) return;

    setState(() => _isLoadingStats = true);
    try {
      final stats = await _userService.getUserStats(_userProfile!['id']);
      setState(() {
        _userStats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      print('Error loading user stats: $e');
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadUserPosts() async {
    if (_userProfile == null) return;

    setState(() => _isLoadingPosts = true);
    try {
      // Get posts from Supabase for this user
      final posts = await Supabase.instance.client
          .from('posts')
          .select()
          .eq('user_id', _userProfile!['id'])
          .order('created_at', ascending: false)
          .limit(20);

      setState(() {
        _userPosts = List<Map<String, dynamic>>.from(posts);
        _isLoadingPosts = false;
      });
    } catch (e) {
      print('Error loading user posts: $e');
      setState(() => _isLoadingPosts = false);
    }
  }

  String _getAvatarLetter() {
    final name = _userProfile?['name'] ?? 'User';
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
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
        const SizedBox(height: 4),
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

  bool get _isOwnProfile {
    final currentUser = Supabase.instance.client.auth.currentUser;
    return widget.userId == null || widget.userId == currentUser?.id;
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        title: Text(_isOwnProfile ? 'Profile' : '${_userProfile?['name'] ?? 'User'}', style: TextStyle(color: Colors.white)),
        foregroundColor: Colors.white,
        actions: _isOwnProfile ? [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              Map<String, String> userInfo;

              if (_userProfile != null) {
                userInfo = Map<String, String>.from(
                  _userProfile!.map((k, v) => MapEntry(k, v?.toString() ?? '')),
                );
              } else {
                // Create basic profile if it doesn't exist
                final user = Supabase.instance.client.auth.currentUser;
                if (user != null) {
                  try {
                    // Create a basic profile
                    await _userService.saveUserInfo(
                      name: user.email?.split('@')[0] ?? 'User',
                      role: 'Member',
                      email: user.email ?? '',
                    );

                    // Reload profile
                    await _loadUserProfile();

                    if (_userProfile != null) {
                      userInfo = Map<String, String>.from(
                        _userProfile!.map((k, v) => MapEntry(k, v?.toString() ?? '')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to create profile. Please try again.')),
                      );
                      return;
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create profile: $e')),
                    );
                    return;
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User not authenticated')),
                  );
                  return;
                }
              }

              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfileScreen(userInfo: userInfo),
                  ),
                ).then((result) {
                  // Always reload profile data since edit screen may have updated database
                  _loadUserProfile();
                });
              }
            },
          ),
        ] : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Picture and Basic Info
            _isOwnProfile ? GestureDetector(
              onTap: () async {
                Map<String, String> userInfo;

                if (_userProfile != null) {
                  userInfo = Map<String, String>.from(
                    _userProfile!.map((k, v) => MapEntry(k, v?.toString() ?? '')),
                  );
                } else {
                  // Create basic profile if it doesn't exist
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user != null) {
                    try {
                      // Create a basic profile
                      await _userService.saveUserInfo(
                        name: user.email?.split('@')[0] ?? 'User',
                        role: 'Member',
                        email: user.email ?? '',
                      );

                      // Reload profile
                      await _loadUserProfile();

                      if (_userProfile != null) {
                        userInfo = Map<String, String>.from(
                          _userProfile!.map((k, v) => MapEntry(k, v?.toString() ?? '')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to create profile. Please try again.')),
                        );
                        return;
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to create profile: $e')),
                      );
                      return;
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User not authenticated')),
                    );
                    return;
                  }
                }

                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(userInfo: userInfo),
                    ),
                  ).then((result) {
                     // Always reload profile data since edit screen may have updated database
                     _loadUserProfile();
                   });
                }
              },
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFF1E3A8A),
                    backgroundImage:
                        _userProfile?['profile_picture_url'] != null
                            ? NetworkImage(_userProfile!['profile_picture_url'])
                            : null,
                    child: _userProfile?['profile_picture_url'] == null
                        ? Text(
                            _getAvatarLetter(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
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
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ) : CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFF1E3A8A),
              backgroundImage:
                  _userProfile?['profile_picture_url'] != null
                      ? NetworkImage(_userProfile!['profile_picture_url'])
                      : null,
              child: _userProfile?['profile_picture_url'] == null
                  ? Text(
                      _getAvatarLetter(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              _userProfile?['name'] ?? user?.email?.split('@')[0] ?? 'User',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _userProfile?['email'] ?? user?.email ?? '',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            if (_userProfile?['bio'] != null &&
                _userProfile!['bio'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _userProfile!['bio'],
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),

            // Stats Row (Posts, Followers, Following)
            if (!_isLoadingStats) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('Posts', _userStats['posts'] ?? 0),
                  _buildStatColumn('Followers', _userStats['followers'] ?? 0),
                  _buildStatColumn('Following', _userStats['following'] ?? 0),
                ],
              ),
              const SizedBox(height: 30),
            ],

            // User's Posts Section
            if (!_isLoadingPosts && _userPosts.isNotEmpty) ...[
              const Text(
                'Posts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _userPosts.length,
                  itemBuilder: (context, index) {
                    final post = _userPosts[index];
                    return Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: post['image_url'] != null && post['image_url'].isNotEmpty
                            ? Image.network(
                                post['image_url'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.image, size: 50, color: Colors.grey),
                              )
                            : post['video_url'] != null && post['video_url'].isNotEmpty
                                ? Container(
                                    color: Colors.black,
                                    child: const Icon(Icons.play_circle_fill, size: 50, color: Colors.white),
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      post['content'] ?? 'Post',
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],

            // About Section (only show for full profile view)
            if (widget.showFullProfile) ...[
              const Text(
                'About',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Profile Details Cards
              if (_userProfile?['church_name'] != null &&
                  _userProfile!['church_name'].isNotEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.church, color: Color(0xFF1E3A8A)),
                    title: Text(_userProfile!['church_name']),
                    subtitle:
                        Text(_userProfile?['position_in_church'] ?? 'Member'),
                  ),
                ),

              // Only show phone for own profile
              if (_isOwnProfile && _userProfile?['phone'] != null &&
                  _userProfile!['phone'].isNotEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.phone, color: Color(0xFF1E3A8A)),
                    title: const Text('Phone'),
                    subtitle: Text(_userProfile!['phone']),
                  ),
                ),

              if (_userProfile?['relationship_status'] != null &&
                  _userProfile!['relationship_status'].isNotEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.red),
                    title: const Text('Relationship Status'),
                    subtitle: Text(_userProfile!['relationship_status']),
                  ),
                ),

              if (_userProfile?['birthday'] != null &&
                  _userProfile!['birthday'].isNotEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cake, color: Colors.pink),
                    title: const Text('Birthday'),
                    subtitle: Text(_userProfile!['birthday']),
                  ),
                ),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF1E3A8A)),
                  title: const Text('Role'),
                  subtitle: Text(_userProfile?['role'] ?? 'Member'),
                ),
              ),

              // Only show email for own profile
              if (_isOwnProfile)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.email, color: Color(0xFF1E3A8A)),
                    title: const Text('Email'),
                    subtitle: Text(_userProfile?['email'] ?? ''),
                  ),
                ),
            ],

            // Action Buttons (only show for own profile and full profile view)
            if (_isOwnProfile && widget.showFullProfile) ...[
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.bookmark, color: Color(0xFF1E3A8A)),
                      title: const Text('Bible Bookmarks'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BookmarksScreen(bibleService: BibleService()),
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
                            builder: (context) =>
                                NotesScreen(bibleService: BibleService()),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.settings, color: Color(0xFF1E3A8A)),
                      title: const Text('Settings'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SettingsScreen(userInfo: const {}),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.history, color: Color(0xFF1E3A8A)),
                      title: const Text('Prayer History'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Prayer history coming soon!')),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.help, color: Color(0xFF1E3A8A)),
                      title: const Text('Help & Support'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Help & support coming soon!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Sign Out Button (only show for own profile and full profile view)
            if (_isOwnProfile && widget.showFullProfile) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
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
            ],
          ],
        ),
      ),
    );
  }
}
