import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase/supabase.dart';
import 'services/church_service.dart';
import 'services/user_service.dart';
import 'services/notification_service.dart';
import 'services/call_manager.dart';
import 'create_church_screen.dart';
import 'facebook_home_screen.dart';
import 'widgets/church_profile_picture_editor.dart';
import 'widgets/call_screen.dart';
import 'live_stream_screen.dart';
import 'church_group_chat_page.dart';
import 'chat_page.dart';

class PastorDashboard extends StatefulWidget {
  final Map<String, String> userInfo;

  const PastorDashboard({super.key, required this.userInfo});

  @override
  State<PastorDashboard> createState() => _PastorDashboardState();
}

class _PastorDashboardState extends State<PastorDashboard> {
  final ChurchService _churchService = ChurchService();
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();
  final CallManager _callManager = CallManager();
  int _currentTabIndex = 0;
  Map<String, dynamic>? _churchData;
  bool _isLoading = true;
  bool _isPastor = false;
  int? _userCount;

  @override
  void initState() {
    super.initState();
    _loadChurchData();
    _checkUserRole();
    _callManager.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh church data when the widget comes back into focus
    _loadChurchData();
  }

  Future<void> _checkUserRole() async {
    final isPastor = await _userService.isUserPastor();
    print('DEBUG PastorDashboard._checkUserRole: About to call setState, mounted: $mounted');
    if (mounted) {
      setState(() {
        _isPastor = isPastor;
      });
    } else {
      print('DEBUG PastorDashboard._checkUserRole: Widget not mounted, skipping setState');
    }
  }

  Future<void> _loadChurchData() async {
    try {
      final userInfo = await _userService.getUserInfo();
      print('DEBUG PastorDashboard._loadChurchData: userInfo = $userInfo');
      if (userInfo != null && userInfo['id'] != null) {
        print('DEBUG PastorDashboard._loadChurchData: Calling getChurchByPastorId with ID: ${userInfo['id']}');
        final churchData = await _churchService.getChurchByPastorId(userInfo['id']);
        print('DEBUG PastorDashboard._loadChurchData: churchData = $churchData');
        print('DEBUG PastorDashboard._loadChurchData: profile_picture_url from churchData: ${churchData?['profile_picture_url']}');
        if (churchData == null) {
          print('DEBUG PastorDashboard._loadChurchData: churchData is null, checking if church exists');
        }
        print('DEBUG PastorDashboard._loadChurchData: member_count from churchData: ${churchData?['member_count']}');
        print('DEBUG PastorDashboard._loadChurchData: About to call setState, mounted: $mounted');
        if (mounted) {
          final oldProfileUrl = _churchData?['profile_picture_url'];
          setState(() {
            _churchData = churchData;
            _isLoading = false;
          });
          print('DEBUG PastorDashboard._loadChurchData: State updated successfully');
          print('DEBUG PastorDashboard._loadChurchData: Profile URL change: $oldProfileUrl -> ${_churchData?['profile_picture_url']}');
        } else {
          print('DEBUG PastorDashboard._loadChurchData: Widget not mounted, skipping setState');
        }
      } else {
        print('DEBUG PastorDashboard._loadChurchData: userInfo is null or missing id');
        print('DEBUG PastorDashboard._loadChurchData: About to call setState (error case), mounted: $mounted');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        } else {
          print('DEBUG PastorDashboard._loadChurchData: Widget not mounted, skipping setState (error case)');
        }
      }

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
    } catch (e) {
      print('Error loading church data: $e');
      print('DEBUG PastorDashboard._loadChurchData: About to call setState (catch), mounted: $mounted');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      } else {
        print('DEBUG PastorDashboard._loadChurchData: Widget not mounted, skipping setState (catch)');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading church data: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pastor Dashboard'),
            if (_userCount != null) ...[
              const SizedBox(width: 8),
              Text(
                '($_userCount people)',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => FacebookHomeScreen(
                    userInfo: widget.userInfo,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _churchData == null
              ? _buildNoChurchView()
              : _buildDashboardWithChurch(),
      floatingActionButton: _isPastor && _churchData != null
          ? FloatingActionButton(
              onPressed: _showLiveStreamDialog,
              backgroundColor: const Color(0xFF1E3A8A),
              child: const Icon(Icons.live_tv, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildNoChurchView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.church, size: 64, color: Color(0xFF1E3A8A)),
            const SizedBox(height: 16),
            Text(
              'Welcome, ${widget.userInfo['name'] ?? 'Pastor'}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You haven\'t created a church yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your church profile to start managing your congregation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateChurchScreen(userInfo: widget.userInfo),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Create Church'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardWithChurch() {
    return Column(
      children: [
        // Church header
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E3A8A).withOpacity(0.1),
          child: Row(
            children: [
              ChurchProfilePictureEditor(
                imageUrl: _churchData!['profile_picture_url'],
                onImageSelected: (file) async {
                  print('DEBUG PastorDashboard.ChurchProfilePictureEditor.onImageSelected: Callback triggered');
                  print('DEBUG PastorDashboard.ChurchProfilePictureEditor.onImageSelected: File received: ${file.path}');
                  print('DEBUG PastorDashboard.ChurchProfilePictureEditor.onImageSelected: Church ID: ${_churchData!['id']}');
                  print('DEBUG PastorDashboard.ChurchProfilePictureEditor.onImageSelected: Current profile_picture_url: ${_churchData!['profile_picture_url']}');

                  final url = await _churchService.uploadChurchProfilePicture(
                      file, _churchData!['id']);

                  print('DEBUG PastorDashboard.ChurchProfilePictureEditor.onImageSelected: Upload result URL: $url');
                  print('DEBUG PastorDashboard.ChurchProfilePictureEditor.onImageSelected: Upload result type check: ${url?.runtimeType}');

                  if (url != null && url.isNotEmpty) {
                    print('DEBUG PastorDashboard.ChurchProfilePictureEditor.onImageSelected: Upload successful, new URL: $url');
                    print('DEBUG PastorDashboard.ChurchProfilePictureEditor: About to call setState, mounted: $mounted');

                    if (mounted) {
                      final oldUrl = _churchData!['profile_picture_url'];
                      setState(() {
                        _churchData!['profile_picture_url'] = url;
                      });
                      print('DEBUG PastorDashboard.ChurchProfilePictureEditor.onImageSelected: State updated successfully');
                      print('DEBUG PastorDashboard.ChurchProfilePictureEditor.onImageSelected: Old URL: $oldUrl -> New URL: ${_churchData!['profile_picture_url']}');

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Church profile picture updated successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      print('DEBUG PastorDashboard.ChurchProfilePictureEditor: Widget not mounted, skipping setState');
                    }
                  } else {
                    print('DEBUG PastorDashboard.ChurchProfilePictureEditor.onImageSelected: Upload failed or returned null/empty URL');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to upload church profile picture. Please try again.'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _churchData!['church_name'] ?? 'Church',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    FutureBuilder<Map<String, int>>(
                      future: _churchService.getChurchStats(_churchData!['id']),
                      builder: (context, snapshot) {
                        final memberCount = snapshot.data?['members'] ?? 0;
                        print('DEBUG PastorDashboard FutureBuilder: memberCount = $memberCount, snapshot.hasData = ${snapshot.hasData}, snapshot.hasError = ${snapshot.hasError}');
                        if (snapshot.hasError) {
                          print('DEBUG PastorDashboard FutureBuilder error: ${snapshot.error}');
                        }
                        return Text(
                          '$memberCount members',
                          style: const TextStyle(color: Colors.grey),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChipTab('Overview', 0, Icons.dashboard),
                const SizedBox(width: 8),
                _buildChipTab('Members', 1, Icons.people),
                const SizedBox(width: 8),
                _buildChipTab('Notifications', 2, Icons.notifications),
              ],
            ),
          ),
        ),

        // Tab content
        Expanded(
          child: IndexedStack(
            index: _currentTabIndex,
            children: [
              _buildOverviewTab(),
              _buildMembersTab(),
              _buildNotificationsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChipTab(String title, int index, IconData icon) {
    final isSelected = _currentTabIndex == index;
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) {
        print('DEBUG PastorDashboard._buildChipTab: About to call setState (tab change), mounted: $mounted');
        if (mounted) {
          setState(() => _currentTabIndex = index);
        } else {
          print('DEBUG PastorDashboard._buildChipTab: Widget not mounted, skipping setState (tab change)');
        }
      },
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
      ),
      label: Text(
        title,
        style: const TextStyle(fontSize: 12),
      ),
      selectedColor: const Color(0xFF1E3A8A),
      backgroundColor: const Color(0xFFEFF2F9),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      shape: StadiumBorder(
        side: BorderSide(color: const Color(0xFF1E3A8A).withOpacity(0.4)),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Church Overview',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          FutureBuilder<Map<String, int>>(
            future: _churchService.getChurchStats(_churchData!['id']),
            builder: (context, snapshot) {
              final stats = snapshot.data ?? {'members': 0, 'visitors': 0, 'events': 0};

              return LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final isSmallScreen = screenWidth < 400;
                  final crossAxisCount = isSmallScreen ? 1 : 2;

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: isSmallScreen ? 8 : 16,
                    mainAxisSpacing: isSmallScreen ? 8 : 16,
                    childAspectRatio: isSmallScreen ? 2.5 : 1.0,
                    children: [
                      _buildStatCard('Total Members', '${stats['members']}', Icons.people, isSmallScreen: isSmallScreen),
                      _buildStatCard('Visitors', '${stats['visitors']}', Icons.person_add, isSmallScreen: isSmallScreen),
                      _buildStatCard('Events', '${stats['events']}', Icons.event, isSmallScreen: isSmallScreen),
                      _buildStatCard('Ministries', '${_churchData!['ministries']?.length ?? 0}', Icons.group, isSmallScreen: isSmallScreen),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),

          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _churchService.getPastorNotifications(_churchData!['pastor_id']),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Error loading notifications');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              final notifications = snapshot.data ?? [];

              if (notifications.isEmpty) {
                return const Text('No recent activity');
              }

              return Column(
                children: notifications.take(5).map((notification) {
                  return ListTile(
                    leading: const Icon(Icons.notifications, color: Colors.blue),
                    title: Text(notification['message'] ?? 'Notification'),
                    subtitle: Text(_formatTimestamp(notification['created_at'])),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    print('DEBUG PastorDashboard._buildMembersTab: Building members tab for churchId: ${_churchData!['id']}');
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _churchService.getChurchMembers(_churchData!['id'] ?? ''),
      builder: (context, snapshot) {
        print('DEBUG PastorDashboard._buildMembersTab StreamBuilder: hasData=${snapshot.hasData}, hasError=${snapshot.hasError}, connectionState=${snapshot.connectionState}');
        if (snapshot.hasError) {
          print('DEBUG PastorDashboard._buildMembersTab: Error: ${snapshot.error}');
          return const Center(child: Text('Error loading members'));
        }

        if (!snapshot.hasData) {
          print('DEBUG PastorDashboard._buildMembersTab: No data yet, showing loading');
          return const Center(child: CircularProgressIndicator());
        }

        final members = snapshot.data!;
        print('DEBUG PastorDashboard._buildMembersTab: Received ${members.length} members');
        if (members.isNotEmpty) {
          print('DEBUG PastorDashboard._buildMembersTab: First member data: ${members[0]}');
        }

        return ListView.builder(
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final userId = member['user_id'] as String?;
            print('DEBUG PastorDashboard._buildMembersTab: Building item $index: userId=$userId');

            return FutureBuilder<Map<String, dynamic>?>(
              future: userId != null ? _getUserData(userId) : null,
              builder: (context, userSnapshot) {
                final userData = userSnapshot.data;
                final displayName = userData?['name'] ?? 'Unknown Member';
                final displayEmail = userData?['email'] ?? userId ?? '';
                final profilePictureUrl = userData?['profile_picture_url'];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    backgroundImage: profilePictureUrl != null ? NetworkImage(profilePictureUrl) : null,
                    child: profilePictureUrl == null ? Text(
                      displayName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ) : null,
                  ),
                  title: Text(displayName),
                  subtitle: Text(displayEmail),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.call, color: Colors.blue),
                        tooltip: 'Audio Call',
                        onPressed: () async {
                          final callId = await _callManager.startCall(
                            recipientId: userId!,
                            callType: CallType.audio,
                          );
                          if (callId != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => CallScreen(
                                  callId: callId,
                                  isIncoming: false,
                                  otherUserId: userId,
                                  otherUserName: displayName,
                                  otherUserProfilePicture: profilePictureUrl,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to start call')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.message, color: Colors.blue),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                otherUserId: userId!,
                                otherUserName: displayName,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }




  Widget _buildNotificationsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _churchService.getPastorNotifications(_churchData!['pastor_id']),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading notifications'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final notifications = snapshot.data ?? [];
        if (notifications.isEmpty) {
          return const Center(child: Text('No notifications'));
        }
        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            final title = notification['title'] ?? '';
            final message = notification['message'] ?? 'Notification';
            final displayText = title.isNotEmpty ? '$title $message' : message;

            return ListTile(
              leading: const Icon(Icons.notifications, color: Colors.blue),
              title: Text(displayText),
              subtitle: Text(_formatTimestamp(notification['created_at'])),
              trailing: notification['is_read'] == true
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.mark_email_read),
                      onPressed: () {
                        _churchService.markNotificationAsRead(notification['id']);
                      },
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, {required bool isSmallScreen}) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isSmallScreen ? 24 : 32, color: const Color(0xFF1E3A8A)),
            SizedBox(height: isSmallScreen ? 4 : 8),
            Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey,
                fontSize: isSmallScreen ? 12 : 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  void _showLiveStreamDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Start Live Stream'),
          content: const Text('Choose your audience:'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startLiveStream('everyone');
              },
              child: const Text('Stream to Everyone'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startLiveStream('church_members');
              },
              child: const Text('Stream to Church Members'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _startLiveStream(String audience) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting live stream for $audience...'),
        duration: const Duration(seconds: 2),
      ),
    );

    if (audience == 'church_members') {
      _notifyChurchMembers();
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LiveStreamScreen(
          audience: audience,
          pastorName: widget.userInfo['name'] ?? 'Pastor',
          churchId: _churchData!['id'],
        ),
      ),
    );
  }

  Future<void> _notifyChurchMembers() async {
    try {
      await _notificationService.sendNotificationToChurchMembers(
        churchId: _churchData!['id'],
        title: 'Live Stream Started!',
        body: '${widget.userInfo['name'] ?? 'Your Pastor'} is now streaming live. Join now!',
        data: {
          'type': 'live_stream',
          'pastor_name': widget.userInfo['name'] ?? 'Your Pastor',
          'church_id': _churchData!['id'],
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notified church members about the live stream!'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error notifying church members: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('name, email, profile_picture_url')
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      print('Error fetching user data for $userId: $e');
      return null;
    }
  }

}