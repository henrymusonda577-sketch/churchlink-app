import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'services/notification_service.dart';
import 'services/user_service.dart';

class NotificationsScreen extends StatefulWidget {
  final Map<String, String> userInfo;

  const NotificationsScreen({super.key, required this.userInfo});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late NotificationService _notificationService;
  late StreamSubscription<List<Map<String, dynamic>>> _notificationsSubscription;
  final UserService _userService = UserService();
  final Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _loadNotifications();
    _listenForNewNotifications();
  }

  @override
  void dispose() {
    _notificationsSubscription.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      // Get initial notifications
      final notifications = await _notificationService.getNotifications().first;
      await _fetchUserNamesForNotifications(notifications);
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _listenForNewNotifications() {
    // Listen to real-time notifications stream
    _notificationsSubscription = _notificationService.getNotifications().listen((notifications) async {
      await _fetchUserNamesForNotifications(notifications);
      setState(() {
        _notifications = notifications;
      });
    });

    // Listen to new notification messages for sound
    _notificationService.messageStream.listen((notification) {
      _playNotificationSound();
    });
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('notification_sound.mp3'));
    } catch (e) {
      print('Error playing notification sound: $e');
    }
  }

  Future<void> _fetchUserNamesForNotifications(List<Map<String, dynamic>> notifications) async {
    final userIdsToFetch = <String>{};

    for (final notification in notifications) {
      final fromUserId = notification['from_user_id'];
      if (fromUserId != null && !_userNameCache.containsKey(fromUserId)) {
        userIdsToFetch.add(fromUserId);
      }
    }

    if (userIdsToFetch.isNotEmpty) {
      for (final userId in userIdsToFetch) {
        try {
          final userData = await _userService.getUserById(userId);
          if (userData != null && userData['name'] != null) {
            _userNameCache[userId] = userData['name'];
          } else {
            _userNameCache[userId] = 'Unknown User';
          }
        } catch (e) {
          print('Error fetching user name for $userId: $e');
          _userNameCache[userId] = 'Unknown User';
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No notifications',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'re all caught up!',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final type = notification['type'] ?? '';
                    final title = notification['title'] ?? '';
                    final message = notification['message'] ?? '';
                    final fromUserId = notification['from_user_id'];
                    final isRead = notification['is_read'] ?? false;
                    final timestamp = notification['created_at'] != null
                        ? DateTime.parse(notification['created_at'])
                        : null;

                    // Get user name from cache or fallback
                    final fromUser = fromUserId != null ? (_userNameCache[fromUserId] ?? 'User') : 'System';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isRead ? Colors.white : Colors.blue[50],
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1E3A8A),
                          child: Text(
                            fromUser.isNotEmpty && fromUser != 'User' && fromUser != 'Unknown User'
                                ? fromUser[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        title: Text(
                          fromUser,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(message),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(timestamp),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: !isRead
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E3A8A),
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        onTap: () async {
                          if (!isRead) {
                            try {
                              await _notificationService.markNotificationAsRead(notification['id']);
                              // The stream will update the UI automatically
                            } catch (e) {
                              print('Error marking notification as read: $e');
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final difference = now.difference(timestamp);

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
}
