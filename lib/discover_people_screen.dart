import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/user_service.dart';

class DiscoverPeopleScreen extends StatefulWidget {
  final Map<String, String> userInfo;

  const DiscoverPeopleScreen({super.key, required this.userInfo});

  @override
  State<DiscoverPeopleScreen> createState() => _DiscoverPeopleScreenState();
}

class _DiscoverPeopleScreenState extends State<DiscoverPeopleScreen> {
  final UserService _userService = UserService();
  List<Map<String, dynamic>> _discoverableUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, bool> _followingStatus = {};

  @override
  void initState() {
    super.initState();
    _loadDiscoverableUsers();
  }

  String _getAvatarLetter(String name) {
    if (name.isNotEmpty && name.trim().isNotEmpty) {
      final firstChar = name.trim()[0].toUpperCase();
      // Avoid showing 'U' if the first letter happens to be 'U'
      return firstChar != 'U'
          ? firstChar
          : (name.length > 1 ? name[1].toUpperCase() : 'A');
    }
    return 'A'; // Default fallback
  }

  Future<void> _loadDiscoverableUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _userService.getDiscoverableUsers();

      // Check following status for each user
      final Map<String, bool> followingStatus = {};
      for (final user in users) {
        final userId = user['id'] ?? user['uid'] ?? '';
        if (userId.isNotEmpty) {
          final isFollowing = await _userService.isFollowing(userId);
          followingStatus[userId] = isFollowing;
        }
      }

      setState(() {
        _discoverableUsers = users;
        _followingStatus = followingStatus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load users: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollowUser(String userId, String userName) async {
    final isCurrentlyFollowing = _followingStatus[userId] ?? false;

    try {
      if (isCurrentlyFollowing) {
        await _userService.unfollowUser(userId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You unfollowed $userName'),
            backgroundColor: Colors.grey,
          ),
        );
      } else {
        await _userService.followUser(userId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are now following $userName!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Update the following status locally
      setState(() {
        _followingStatus[userId] = !isCurrentlyFollowing;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${isCurrentlyFollowing ? 'unfollow' : 'follow'} user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToProfile(Map<String, dynamic> user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing ${user['name']} profile')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover People'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDiscoverableUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 80,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDiscoverableUsers,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _discoverableUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No users to discover',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check back later for new members',
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _discoverableUsers.length,
                      itemBuilder: (context, index) {
                        final user = _discoverableUsers[index];
                        final userId = user['id'] ?? user['uid'] ?? '';
                        final userName = user['name'] ?? 'Unknown User';
                        final userRole = user['role'] ?? 'Member';
                        final churchName = user['church_name'] ?? user['churchName'] ?? '';
                        final profilePictureUrl = user['profile_picture_url'] ?? user['profilePictureUrl'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: profilePictureUrl != null
                                  ? NetworkImage(profilePictureUrl)
                                  : null,
                              child: profilePictureUrl == null
                                  ? Text(
                                      _getAvatarLetter(userName),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.person),
                                  onPressed: () => _navigateToProfile(user),
                                  tooltip: 'View Profile',
                                ),
                                ElevatedButton(
                                  onPressed: () => _toggleFollowUser(userId, userName),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: (_followingStatus[userId] ?? false)
                                        ? Colors.grey[600]
                                        : const Color(0xFF1E3A8A),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: Text(_followingStatus[userId] ?? false ? 'Following' : 'Follow'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
