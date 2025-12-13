import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase/supabase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'profile_screen.dart';
import 'bible_screen.dart';
import 'chat_screen.dart';
import 'community_screen.dart';
import 'create_post_screen.dart';
import 'events_screen.dart';
import 'notifications_screen.dart';
import 'discover_people_screen.dart';
import 'live_streams_browser_screen.dart';
import 'prayer_form_screen.dart';
import 'content_screen.dart';
import 'story_viewer_screen.dart';
import 'church_group_chat_page.dart';
import 'services/post_service.dart';
import 'services/user_service.dart';
import 'services/community_service.dart';
import 'services/church_service.dart';
import 'services/notification_service.dart';
import 'pastor_dashboard.dart';
import 'widgets/post_widget.dart';

// Import mock classes from PostService
import 'services/post_service.dart' show MockQuerySnapshot, MockQueryDocumentSnapshot;

class FacebookHomeScreen extends StatefulWidget {
  final Map<String, String>? userInfo;

  const FacebookHomeScreen({super.key, this.userInfo});

  @override
  State<FacebookHomeScreen> createState() => _FacebookHomeScreenState();
}

class _FacebookHomeScreenState extends State<FacebookHomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final PostService _postService = PostService();
  final UserService _userService = UserService();
  final CommunityService _communityService = CommunityService();
  final ChurchService _churchService = ChurchService();
  final NotificationService _notificationService = NotificationService();
  Map<String, String> _userInfo = {};
  bool _isLoadingUserInfo = true;
  int _unreadNotificationsCount = 0;
  int? _userCount;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserInfo();
    _loadUnreadNotificationsCount();
    _listenForNotificationUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh user info when app resumes (user might have joined church from another screen)
      print('DEBUG FacebookHomeScreen: App resumed, refreshing user info');
      _loadUserInfo();
      _loadUnreadNotificationsCount();
    }
  }

  Future<void> _loadUserInfo() async {
    print('DEBUG FacebookHomeScreen._loadUserInfo: Starting to load user info');
    try {
      final userData = await _userService.getUserInfo();
      print('DEBUG FacebookHomeScreen._loadUserInfo: User data from service: $userData');

      if (userData != null && mounted) {
        final mappedUserInfo = userData.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        );
        print('DEBUG FacebookHomeScreen._loadUserInfo: Mapped user info: $mappedUserInfo');
        setState(() {
          _userInfo = mappedUserInfo;
          _isLoadingUserInfo = false;
        });
        print('DEBUG FacebookHomeScreen._loadUserInfo: Set state with user data, role: ${_userInfo['role']}, church_id: ${_userInfo['church_id']}, church_name: ${_userInfo['church_name']}');

        // Fetch user count for specific email
        final userEmail = Supabase.instance.client.auth.currentUser?.email;
        if (userEmail == 'henrymusonda577@gmail.com') {
          try {
            final userCountResponse = await Supabase.instance.client
                .from('users')
                .select('id')
                .count(CountOption.exact);
            if (mounted) {
              setState(() {
                _userCount = userCountResponse.count;
              });
            }
          } catch (e) {
            print('Error fetching user count: $e');
          }
        }
      } else {
        // Fallback to widget userInfo or default
        print('DEBUG FacebookHomeScreen._loadUserInfo: No user data from service, using fallback');
        if (mounted) {
          final fallbackInfo = widget.userInfo ?? {'role': 'Member'};
          print('DEBUG FacebookHomeScreen._loadUserInfo: Fallback user info: $fallbackInfo');
          setState(() {
            _userInfo = fallbackInfo;
            _isLoadingUserInfo = false;
          });
        }
      }
    } catch (e) {
      print('DEBUG FacebookHomeScreen._loadUserInfo: Error loading user info: $e');
      if (mounted) {
        final fallbackInfo = widget.userInfo ?? {'role': 'Member'};
        print('DEBUG FacebookHomeScreen._loadUserInfo: Using fallback due to error: $fallbackInfo');
        setState(() {
          _userInfo = fallbackInfo;
          _isLoadingUserInfo = false;
        });
      }
    }
  }

  Future<void> _loadUnreadNotificationsCount() async {
    try {
      final count = await _notificationService.getUnreadNotificationsCount();
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = count;
        });
      }
    } catch (e) {
      print('Error loading unread notifications count: $e');
    }
  }

  void _listenForNotificationUpdates() {
    // Listen for notification changes to update badge in real-time
    _notificationService.getNotifications().listen((notifications) async {
      // Update the unread count when notifications change
      final unreadCount = notifications.where((n) => n['is_read'] == false).length;
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = unreadCount;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      // Search for users and churches simultaneously
      final userResults = await _userService.searchUsers(query);
      final churchResults = await _churchService.searchChurches(query);

      // Combine results with type indicators
      final combinedResults = <Map<String, dynamic>>[];

      // Add users with type indicator
      for (final user in userResults) {
        combinedResults.add({
          ...user,
          'type': 'user',
        });
      }

      // Add churches with type indicator
      for (final church in churchResults) {
        combinedResults.add({
          ...church,
          'type': 'church',
        });
      }

      if (mounted) {
        setState(() {
          _searchResults = combinedResults;
          _showSearchResults = true;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Error performing search: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
          _isSearching = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _showSearchResults = false;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.of(context).size.width;
            final isSmallScreen = screenWidth < 400;
            final isMediumScreen = screenWidth < 600;

            return AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.church, size: isSmallScreen ? 20 : 24),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isSmallScreen ? 'Church' : 'Church-Link',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 18,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_userCount != null)
                          Text(
                            '$_userCount people',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 12,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
              actions: [
                // Notifications - always show
                Stack(
                  children: [
                    IconButton(
                      iconSize: isSmallScreen ? 20 : 24,
                      icon: const Icon(Icons.notifications),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NotificationsScreen(userInfo: _userInfo),
                          ),
                        ).then((_) {
                          // Refresh unread count when returning from notifications screen
                          _loadUnreadNotificationsCount();
                        });
                      },
                    ),
                    if (_unreadNotificationsCount > 0)
                      Positioned(
                        right: isSmallScreen ? 6 : 8,
                        top: isSmallScreen ? 6 : 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            _unreadNotificationsCount > 99
                                ? '99+'
                                : _unreadNotificationsCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 8 : 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                // People icon - now always show (removed screen size restriction)
                IconButton(
                  iconSize: 20,
                  icon: const Icon(Icons.people),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DiscoverPeopleScreen(userInfo: _userInfo),
                      ),
                    );
                  },
                  tooltip: 'Discover People',
                ),
                // Pastor dashboard - only show if user is a pastor (removed screen size restriction)
                Builder(
                  builder: (context) {
                    final positionInChurch = _userInfo['position_in_church'];
                    final role = _userInfo['role'];
                    final showDashboard = positionInChurch == 'pastor' || role == 'pastor';
                    if (showDashboard) {
                      return IconButton(
                        iconSize: 20,
                        icon: const Icon(Icons.dashboard),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PastorDashboard(
                                userInfo: _userInfo,
                              ),
                            ),
                          );
                        },
                        tooltip: 'Pastor Dashboard',
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // Church icon - only show if user is a member of a church (removed screen size restriction)
                Builder(
                  builder: (context) {
                    final churchId = _userInfo['church_id'];
                    final churchName = _userInfo['church_name'];
                    final positionInChurch = _userInfo['position_in_church'];
                    final showChurchIcon = churchId != null && churchId.isNotEmpty && churchId != 'null';
                    print('DEBUG FacebookHomeScreen: Church icon check - churchId: "$churchId", churchName: "$churchName", positionInChurch: "$positionInChurch", showChurchIcon: $showChurchIcon');
                    print('DEBUG FacebookHomeScreen: All userInfo keys and values: ${_userInfo.entries.map((e) => '${e.key}: "${e.value}"').join(', ')}');
                    if (showChurchIcon) {
                      print('DEBUG FacebookHomeScreen: Showing church icon for church: $churchName');
                      return IconButton(
                        iconSize: 20,
                        icon: const Icon(Icons.church),
                        onPressed: () {
                          print('DEBUG FacebookHomeScreen: Church icon pressed, navigating to chat for church: $churchName');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChurchGroupChatPage(
                                churchId: churchId,
                                churchName: churchName ?? 'Church Group',
                              ),
                            ),
                          );
                        },
                        tooltip: 'Church Group Chat',
                      );
                    } else {
                      print('DEBUG FacebookHomeScreen: Church icon hidden - no valid church_id');
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // Profile avatar - always show
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen(showFullProfile: true)),
                    ).then((_) {
                      // Refresh user info when returning from profile screen
                      _loadUserInfo();
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: isSmallScreen ? 8 : 16),
                    child: CircleAvatar(
                      radius: isSmallScreen ? 14 : 18,
                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.surface
                          : Colors.white,
                      backgroundImage: _userInfo['profile_picture_url'] != null && _userInfo['profile_picture_url']!.isNotEmpty
                          ? NetworkImage(_userInfo['profile_picture_url']!)
                          : null,
                      child: _userInfo['profile_picture_url'] == null || _userInfo['profile_picture_url']!.isEmpty
                          ? Icon(
                              Icons.person,
                              size: isSmallScreen ? 16 : 20,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Theme.of(context).colorScheme.primary
                                  : const Color(0xFF1E3A8A),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          const CommunityScreen(),
          const BibleScreen(),
          const ChatScreen(),
          ContentScreen(userInfo: _userInfo, initialTab: 0),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        iconSize: 20,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Bible'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: 'Videos',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : _selectedIndex == 4
              ? FloatingActionButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ContentScreen(userInfo: _userInfo, initialTab: 0),
                    ),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.video_library, color: Colors.white),
                )
              : null,
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSearchBar(),
          if (_showSearchResults) ...[
            _buildSearchResults(),
          ] else ...[
            _buildQuickActions(),
            _buildVerseOfDay(),
            _buildStoriesSection(),
            _buildPostsFeed(),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 400;

        return Container(
          margin: EdgeInsets.all(isSmallScreen ? 4 : 8),
          child: Wrap(
            spacing: isSmallScreen ? 4 : 8,
            runSpacing: isSmallScreen ? 4 : 8,
            alignment: WrapAlignment.center,
            children: [
              SizedBox(
                width: isSmallScreen ? 60 : 80,
                height: isSmallScreen ? 90 : 120,
                child: _buildQuickActionButton(
                  icon: Icons.live_tv,
                  label: 'Live Stream',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LiveStreamsBrowserScreen(),
                    ),
                  ),
                  isSmallScreen: isSmallScreen,
                ),
              ),
              SizedBox(
                width: isSmallScreen ? 60 : 80,
                height: isSmallScreen ? 90 : 120,
                child: _buildQuickActionButton(
                  icon: Icons.video_library,
                  label: 'Videos',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ContentScreen(userInfo: _userInfo, initialTab: 0),
                    ),
                  ),
                  isSmallScreen: isSmallScreen,
                ),
              ),
              SizedBox(
                width: isSmallScreen ? 60 : 80,
                height: isSmallScreen ? 90 : 120,
                child: _buildQuickActionButton(
                  icon: Icons.event,
                  label: 'Events',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EventsScreen()),
                  ),
                  isSmallScreen: isSmallScreen,
                ),
              ),
              SizedBox(
                width: isSmallScreen ? 60 : 80,
                height: isSmallScreen ? 90 : 120,
                child: _buildQuickActionButton(
                  icon: Icons.favorite,
                  label: 'Prayer',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PrayerFormScreen(userInfo: const {}),
                    ),
                  ),
                  isSmallScreen: isSmallScreen,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surface.withOpacity(0.8)
              : theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(isSmallScreen ? 2 : 3),
          border: Border.all(
            color: isDark
                ? theme.colorScheme.primary.withOpacity(0.5)
                : theme.colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: theme.colorScheme.primary,
              size: isSmallScreen ? 16 : 20,
            ),
            SizedBox(height: isSmallScreen ? 2 : 4),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: isSmallScreen ? 10 : 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 400;

        return Container(
          margin: EdgeInsets.all(isSmallScreen ? 7 : 14),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.white,
            borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              if (value.isNotEmpty) {
                _performSearch(value);
              } else {
                _clearSearch();
              }
            },
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
            ),
            decoration: InputDecoration(
              hintText: isSmallScreen
                  ? 'Search churches & people...'
                  : 'Search for churches and people...',
              hintStyle: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
              ),
              prefixIcon: Icon(
                Icons.search,
                size: isSmallScreen ? 20 : 24,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: isSmallScreen ? 20 : 24,
                      ),
                      onPressed: _clearSearch,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: isSmallScreen ? 12 : 16,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No results found for "$_searchQuery"',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final type = result['type'];

        if (type == 'user') {
          return _buildUserSearchResult(result);
        } else if (type == 'church') {
          return _buildChurchSearchResult(result);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildUserSearchResult(Map<String, dynamic> user) {
    final userName = user['name'] ?? 'Unknown User';
    final userRole = user['role'] ?? 'Member';
    final churchName = user['church_name'] ?? '';
    final profilePictureUrl = user['profile_picture_url'];
    final userId = user['id'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey[300],
          backgroundImage: profilePictureUrl != null
              ? NetworkImage(profilePictureUrl)
              : null,
          child: profilePictureUrl == null
              ? Text(
                  _getAvatarLetter(userName),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                )
              : null,
        ),
        title: Text(
          userName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userRole,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            if (churchName.isNotEmpty)
              Text(
                churchName,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: FutureBuilder<bool>(
          future: _userService.isFollowing(userId),
          builder: (context, snapshot) {
            final isFollowing = snapshot.data ?? false;

            if (isFollowing) {
              return ElevatedButton(
                onPressed: () async {
                  try {
                    await _userService.unfollowUser(userId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unfollowed successfully'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    // Refresh search results
                    if (_searchQuery.isNotEmpty) {
                      await _performSearch(_searchQuery);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to unfollow: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Following'),
              );
            } else {
              return ElevatedButton(
                onPressed: () => _followUser(userId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Follow'),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildChurchSearchResult(Map<String, dynamic> church) {
    final churchName = church['church_name'] ?? 'Unknown Church';
    final denomination = church['denomination'] ?? '';
    final address = church['address'] ?? '';
    final memberCount = church['member_count'] ?? 0;
    final churchId = church['id'];
    final isMember = _userInfo['church_id'] == churchId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.blue[100],
          child: const Icon(
            Icons.church,
            color: Colors.blue,
            size: 25,
          ),
        ),
        title: Text(
          churchName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (denomination.isNotEmpty)
              Text(
                denomination,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            if (address.isNotEmpty)
              Text(
                address,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              '$memberCount members',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: isMember
            ? ElevatedButton(
                onPressed: () {
                  // Navigate to church chat or show member options
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('You are already a member of $churchName')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Member'),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => _joinChurch(churchId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Join'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _visitChurch(churchId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Visit'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _followUser(String userId) async {
    try {
      await _userService.followUser(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow request sent!'),
          backgroundColor: Colors.green,
        ),
      );
      // Refresh search results to update follow status
      if (_searchQuery.isNotEmpty) {
        await _performSearch(_searchQuery);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send follow request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _joinChurch(String churchId) async {
    print('DEBUG FacebookHomeScreen._joinChurch: Before joining - churchId: ${_userInfo['church_id']}, churchName: ${_userInfo['church_name']}');
    try {
      await _churchService.joinChurch(churchId);
      print('DEBUG FacebookHomeScreen._joinChurch: Church service join completed, reloading user info...');

      // Add a small delay to ensure database update is complete
      await Future.delayed(const Duration(milliseconds: 500));

      await _loadUserInfo(); // Reload user info to update church membership
      print('DEBUG FacebookHomeScreen._joinChurch: After joining - churchId: ${_userInfo['church_id']}, churchName: ${_userInfo['church_name']}');

      // Force a rebuild of the app bar to show the church icon
      setState(() {});

      // Refresh search results to update church membership status
      if (_searchQuery.isNotEmpty) {
        await _performSearch(_searchQuery);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully joined church! Church chat is now available in the app bar.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('DEBUG FacebookHomeScreen._joinChurch: Error joining church: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to join church'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _visitChurch(String churchId) async {
    try {
      await _churchService.registerAsVisitor(churchId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registered as visitor!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to register as visitor'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _isUserAdmin() async {
    try {
      return await _userService.isUserAdmin();
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  String _getAvatarLetter(String name) {
    if (name.isNotEmpty && name.trim().isNotEmpty) {
      final firstChar = name.trim()[0].toUpperCase();
      return firstChar != 'U' ? firstChar : (name.length > 1 ? name[1].toUpperCase() : 'A');
    }
    return 'A';
  }

  Widget _buildVerseOfDay() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // List of daily verses
    final verses = [
      {
        'text': '"For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life."',
        'reference': 'John 3:16'
      },
      {
        'text': '"Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight."',
        'reference': 'Proverbs 3:5-6'
      },
      {
        'text': '"I can do all things through Christ who strengthens me."',
        'reference': 'Philippians 4:13'
      },
      {
        'text': '"The Lord is my shepherd, I lack nothing. He makes me lie down in green pastures, he leads me beside quiet waters."',
        'reference': 'Psalm 23:1-2'
      },
      {
        'text': '"Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go."',
        'reference': 'Joshua 1:9'
      },
      {
        'text': '"And we know that in all things God works for the good of those who love him, who have been called according to his purpose."',
        'reference': 'Romans 8:28'
      },
      {
        'text': '"For I know the plans I have for you," declares the Lord, "plans to prosper you and not to harm you, plans to give you hope and a future."',
        'reference': 'Jeremiah 29:11'
      },
      {
        'text': '"But seek first his kingdom and his righteousness, and all these things will be given to you as well."',
        'reference': 'Matthew 6:33'
      },
      {
        'text': '"Come to me, all you who are weary and burdened, and I will give you rest."',
        'reference': 'Matthew 11:28'
      },
      {
        'text': '"Let the peace of Christ rule in your hearts, since as members of one body you were called to peace."',
        'reference': 'Colossians 3:15'
      },
      {
        'text': '"The Lord is close to the brokenhearted and saves those who are crushed in spirit."',
        'reference': 'Psalm 34:18'
      },
      {
        'text': '"Therefore, if anyone is in Christ, the new creation has come: The old has gone, the new is here!"',
        'reference': '2 Corinthians 5:17'
      },
      {
        'text': '"Cast all your anxiety on him because he cares for you."',
        'reference': '1 Peter 5:7'
      },
      {
        'text': '"But those who hope in the Lord will renew their strength. They will soar on wings like eagles."',
        'reference': 'Isaiah 40:31'
      },
      {
        'text': '"Love the Lord your God with all your heart and with all your soul and with all your mind and with all your strength."',
        'reference': 'Mark 12:30'
      },
      {
        'text': '"A friend loves at all times, and a brother is born for a time of adversity."',
        'reference': 'Proverbs 17:17'
      },
      {
        'text': '"For where two or three gather in my name, there am I with them."',
        'reference': 'Matthew 18:20'
      },
      {
        'text': '"The fear of the Lord is the beginning of wisdom, and knowledge of the Holy One is understanding."',
        'reference': 'Proverbs 9:10'
      },
      {
        'text': '"Be kind and compassionate to one another, forgiving each other, just as in Christ God forgave you."',
        'reference': 'Ephesians 4:32'
      },
      {
        'text': '"Let us not become weary in doing good, for at the proper time we will reap a harvest if we do not give up."',
        'reference': 'Galatians 6:9'
      },
      {
        'text': '"And let us consider how we may spur one another on toward love and good deeds."',
        'reference': 'Hebrews 10:24'
      },
      {
        'text': '"Finally, brothers and sisters, whatever is true, whatever is noble, whatever is right, whatever is pure, whatever is lovely, whatever is admirable—if anything is excellent or praiseworthy—think about such things."',
        'reference': 'Philippians 4:8'
      },
      {
        'text': '"But the fruit of the Spirit is love, joy, peace, forbearance, kindness, goodness, faithfulness, gentleness and self-control."',
        'reference': 'Galatians 5:22-23'
      },
      {
        'text': '"Therefore encourage one another and build each other up, just as in fact you are doing."',
        'reference': '1 Thessalonians 5:11'
      },
      {
        'text': '"My grace is sufficient for you, for my power is made perfect in weakness."',
        'reference': '2 Corinthians 12:9'
      },
      {
        'text': '"The Lord your God is with you, the Mighty Warrior who saves. He will take great delight in you; in his love he will no longer rebuke you, but will rejoice over you with singing."',
        'reference': 'Zephaniah 3:17'
      },
      {
        'text': '"For we live by faith, not by sight."',
        'reference': '2 Corinthians 5:7'
      },
      {
        'text': '"Rejoice always, pray continually, give thanks in all circumstances; for this is God\'s will for you in Christ Jesus."',
        'reference': '1 Thessalonians 5:16-18'
      },
      {
        'text': '"Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God."',
        'reference': 'Philippians 4:6'
      },
      {
        'text': '"And now these three remain: faith, hope and love. But the greatest of these is love."',
        'reference': '1 Corinthians 13:13'
      },
    ];

    // Get verse for today (changes every 24 hours)
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final verseIndex = dayOfYear % verses.length;
    final todaysVerse = verses[verseIndex];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF1877F2), Color(0xFF42A5F5)],
              )
            : const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.book, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Verse of the Day',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            todaysVerse['text']!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            todaysVerse['reference']!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoriesSection() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: FutureBuilder<Map<String, Map<String, dynamic>>>(
        future: _fetchUserDataForStories(),
        builder: (context, userDataSnapshot) {
          final userDataMap = userDataSnapshot.data ?? {};
          return StreamBuilder<MockQuerySnapshot>(
            stream: _postService.getStories(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const SizedBox.shrink();
              }

              final stories = snapshot.data?.docs ?? [];

              // Group stories by userId
              final Map<String, List<MockQueryDocumentSnapshot>> storiesByUser = {};
              for (final story in stories) {
                final storyData = story.data();
                final userId = storyData['userId'] as String;
                if (!storiesByUser.containsKey(userId)) {
                  storiesByUser[userId] = [];
                }
                storiesByUser[userId]!.add(story);
              }

              // Get current user ID
              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id ?? '';

              // Create list of user story cards
              final List<Widget> storyCards = [];

              // Always add current user's story card like Instagram
              storyCards.add(
                _buildAddStoryCard(
                  hasStories: storiesByUser.containsKey(currentUserId),
                ),
              );

              // Add other users' story cards
              for (final userId in storiesByUser.keys) {
                if (userId != currentUserId) {
                  storyCards.add(
                    _buildUserStoryCard(userId, storiesByUser[userId]!, userDataMap),
                  );
                }
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: storyCards.length,
                itemBuilder: (context, index) {
                  return storyCards[index];
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<Map<String, Map<String, dynamic>>> _fetchUserDataForStories() async {
    try {
      final stories = await _postService.getStories().first;
      final userIds = <String>{};

      for (final story in stories.docs) {
        final storyData = story.data();
        final userId = storyData['userId'] as String;
        userIds.add(userId);
      }

      final Map<String, Map<String, dynamic>> userDataMap = {};
      if (userIds.isNotEmpty) {
        // Fetch all users and filter in code since .in_() might not be available
        final userResponse = await Supabase.instance.client
            .from('users')
            .select('id, name, profile_picture_url');

        for (final user in userResponse) {
          if (userIds.contains(user['id'])) {
            userDataMap[user['id']] = user;
          }
        }
      }

      return userDataMap;
    } catch (e) {
      print('Error fetching user data for stories: $e');
      return {};
    }
  }

  Widget _buildAddStoryCard({bool hasStories = false}) {
    return GestureDetector(
      onTap: () async {
        if (hasStories) {
          // View own stories
          final currentUserId =
              Supabase.instance.client.auth.currentUser?.id ?? '';
          final stories = await _postService
              .getUserStories(currentUserId)
              .first;
          if (stories.docs.isNotEmpty) {
            // Normalize timestamps for StoryViewerScreen
            final normalizedStories = stories.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                ...data,
                'timestamp': data['timestamp'] is String
                    ? Timestamp.fromDate(DateTime.parse(data['timestamp']))
                    : data['timestamp'],
                'authorName': _userInfo['name'] ?? 'You',
                'authorProfilePicture': _userInfo['profile_picture_url'],
              };
            }).toList();

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StoryViewerScreen(stories: normalizedStories),
              ),
            );
          }
        } else {
          // Create new story
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen(showStoryOption: true)),
          );
        }
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                    border: Border.all(
                      color: hasStories ? Colors.blue : Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.person, size: 35, color: Colors.grey),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your Story',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStoryCard(
    String userId,
    List<MockQueryDocumentSnapshot> userStories,
    Map<String, Map<String, dynamic>> userDataMap,
  ) {
    final storyData = userStories.first.data();
    final userData = userDataMap[userId];
    final profilePictureUrl = storyData['profilePictureUrl'] as String? ?? userData?['profile_picture_url'] as String? ?? '';
    final username = storyData['username'] as String? ?? userData?['name'] ?? 'User';

    return GestureDetector(
      onTap: () {
        // Normalize timestamps for StoryViewerScreen
        final normalizedStories = userStories.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            ...data,
            'timestamp': data['timestamp'] is String
                ? Timestamp.fromDate(DateTime.parse(data['timestamp']))
                : data['timestamp'],
            'authorName': username,
            'authorProfilePicture': profilePictureUrl,
          };
        }).toList();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryViewerScreen(stories: normalizedStories),
          ),
        );
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue, width: 2),
                image: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(profilePictureUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: profilePictureUrl == null || profilePictureUrl.isEmpty
                  ? const Icon(Icons.person, size: 35, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              username.length > 8 ? '${username.substring(0, 8)}...' : username,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsFeed() {
    print('DEBUG: _buildPostsFeed called - using Supabase posts');

    // Get posts from Supabase that were created from the home screen (including videos)
    final postsStream = _communityService.getPostsBySource('home');

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: postsStream,
      builder: (context, snapshot) {
        print('DEBUG: Posts StreamBuilder state: ${snapshot.connectionState}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('DEBUG: Loading posts...');
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('DEBUG: Error in _buildPostsFeed: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error loading posts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? [];
        print('DEBUG: Retrieved ${posts.length} posts');

        if (posts.isEmpty) {
          print('DEBUG: No posts found, showing welcome message');
          final user = Supabase.instance.client.auth.currentUser;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.church, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 20),
                Text(
                  'Welcome to Church-Link',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Hello, ${user?.email ?? 'User'}!',
                  style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tap + to create your first post',
                  style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
              ],
            ),
          );
        }

        print('DEBUG: Building ListView with ${posts.length} posts');
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length + 1,
          itemBuilder: (context, index) {
            if (index == posts.length) {
              // End of feed prompt
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.video_library,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "You've reached the end!",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Share your videos with the community",
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Post'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              );
            }

            final post = posts[index];
            final postId = post['id'];
            // Normalize field names for PostWidget compatibility
            final normalizedPost = {
              ...post,
              'userId': post['user_id'],
              'postType': post['post_type'],
              'imageUrl': post['image_url'],
              'videoUrl': post['video_url'],
              'verseReference': post['verse_reference'],
              'createdAt': post['created_at'],
              'updatedAt': post['updated_at'],
              'type': post['post_type'] ?? 'general',
            };
            print('DEBUG: Building post widget for postId: $postId, type: ${normalizedPost['type']}');

            return PostWidget(postData: normalizedPost, postId: postId);
          },
        );
      },
    );
  }
}
