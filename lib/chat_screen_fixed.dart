import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'dart:async';
import 'services/firebase_chat_service.dart';
import 'services/user_service.dart';
import 'services/call_manager.dart';
import 'discover_people_screen.dart';
import 'widgets/call_screen.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, String> userInfo;

  const ChatScreen({super.key, required this.userInfo});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseChatService _chatService = FirebaseChatService();
  final UserService _userService = UserService();

  // Emoji picker state
  bool _showEmojiPicker = false;

  // Media
  final ImagePicker _imagePicker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State variables
  bool _isPlayingVoice = false;
  String? _currentlyPlayingVoiceUrl;

  // Text controller for message input
  late final TextEditingController _messageController;

  // Audio recording state
  bool _isRecording = false;
  String? _recordedFilePath;
  int _recordedDuration = 0;

  // Import record package
  final _recorder = Record();

  // Helper to get audio duration
  Future<Duration> _getAudioDuration(File file) async {
    final audioPlayer = AudioPlayer();
    final completer = Completer<Duration>();
    audioPlayer.onDurationChanged.listen((duration) {
      completer.complete(duration);
    });
    await audioPlayer.setSourceDeviceFile(file.path);
    return completer.future;
  }

  // Placeholder for video calls tab
  Widget _buildVideoCallsTab() {
    return Center(
      child: Text('Video Calls feature coming soon',
          style: TextStyle(color: Colors.grey)),
    );
  }

  // Navigate to discover people screen
  void _navigateToDiscoverPeople() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DiscoverPeopleScreen(
          userInfo: widget.userInfo,
        ),
      ),
    );
  }

  // ...existing code...

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _messageController = TextEditingController();
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlayingVoice = false;
        _currentlyPlayingVoiceUrl = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Messages'),
            Tab(text: 'Video Calls'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMessagesTab(),
          _buildVideoCallsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'chat_fab',
        onPressed: () => _navigateToDiscoverPeople(),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildMessagesTab() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please sign in to chat.'));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _userService.getUserFollowing(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                const Text(
                  'Error loading chats',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final followingUsers = snapshot.data ?? [];

        if (followingUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No people to chat with',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Follow people to start chatting with them',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DiscoverPeopleScreen(
                          userInfo: widget.userInfo,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Discover People'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: followingUsers.length,
          itemBuilder: (context, index) {
            final user = followingUsers[index];
            final userName = user['name'] ?? 'User';
            final userRole = user['role'] ?? 'Member';
            final profilePictureUrl = user['profilePictureUrl'];

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: profilePictureUrl != null
                          ? NetworkImage(profilePictureUrl)
                          : null,
                      backgroundColor: Colors.grey[300],
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
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(userName),
                subtitle: Text(userRole),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.video_call, color: Colors.grey),
                      onPressed: () => _startVideoCall(user),
                      tooltip: 'Video Call',
                    ),
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.grey),
                      onPressed: () => _startAudioCall(user),
                      tooltip: 'Audio Call',
                    ),
                  ],
                ),
                onTap: () => _showChatDialog(user),
              ),
            );
          },
        );
      },
    );
  }

  void _showChatDialog(Map<String, dynamic> user) {
    final otherUserId = user['uid'];
    final otherUserName = user['name'] ?? 'User';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Chat with $otherUserName'),
          content: SizedBox(
            width: 350,
            height: 400,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('Messages will appear here'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Message input with attachments
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Attachment buttons
                          IconButton(
                            icon: const Icon(Icons.attach_file,
                                color: Colors.grey),
                            onPressed: () {},
                            tooltip: 'Attach file',
                          ),
                          IconButton(
                            icon: const Icon(Icons.image, color: Colors.grey),
                            onPressed: () {},
                            tooltip: 'Send image',
                          ),
                          IconButton(
                            icon: const Icon(Icons.emoji_emotions,
                                color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _showEmojiPicker = !_showEmojiPicker;
                              });
                            },
                            tooltip: 'Emoji',
                          ),

                          // Text input
                          Expanded(
                            child: _recordedFilePath == null
                                ? TextField(
                                    controller: _messageController,
                                    decoration: InputDecoration(
                                      hintText: 'Type a message...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide(
                                            color: Colors.grey[300]!),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    maxLines: 4,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) =>
                                        _sendMessage(otherUserId),
                                  )
                                : Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          _isPlayingVoice
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () async {
                                          if (_isPlayingVoice) {
                                            await _audioPlayer.pause();
                                            setState(() {
                                              _isPlayingVoice = false;
                                            });
                                          } else {
                                            await _audioPlayer.play(
                                                DeviceFileSource(
                                                    _recordedFilePath!));
                                            setState(() {
                                              _isPlayingVoice = true;
                                            });
                                          }
                                        },
                                      ),
                                      Text('Recorded: $_recordedDuration s'),
                                      IconButton(
                                        icon: Icon(Icons.close),
                                        onPressed: () {
                                          setState(() {
                                            _recordedFilePath = null;
                                            _recordedDuration = 0;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                          ),

                          const SizedBox(width: 8),

                          // Send button or stop recording button
                          CircleAvatar(
                            backgroundColor: const Color(0xFF1E3A8A),
                            child: _isRecording
                                ? IconButton(
                                    icon: const Icon(Icons.stop,
                                        color: Colors.white),
                                    onPressed: () async {
                                      final path = await _recorder.stop();
                                      if (path != null) {
                                        final file = File(path);
                                        final duration =
                                            await _getAudioDuration(file);
                                        setState(() {
                                          _recordedFilePath = path;
                                          _recordedDuration =
                                              duration.inSeconds;
                                          _isRecording = false;
                                        });
                                      }
                                    },
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.mic,
                                        color: Colors.white),
                                    onPressed: () async {
                                      bool hasPermission =
                                          await _recorder.hasPermission();
                                      if (hasPermission) {
                                        await _recorder.start();
                                        setState(() {
                                          _isRecording = true;
                                        });
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Microphone permission denied')),
                                        );
                                      }
                                    },
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startAudioCall(user);
              },
              child: const Text('Audio Call'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startVideoCall(user);
              },
              child: const Text('Video Call'),
            ),
          ],
        );
      },
    );
  }

  void _showFeatureDialog(String title, String description) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _sendMessage(String otherUserId) async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      // TODO: Implement message sending
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  // Start video call with user
  void _startVideoCall(Map<String, dynamic> user) async {
    final callManager = Provider.of<CallManager>(context, listen: false);
    final otherUserId = user['uid'];
    final otherUserName = user['name'] ?? 'User';
    final otherUserProfilePicture = user['profilePictureUrl'];

    if (otherUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to start call: User ID not found')),
      );
      return;
    }

    try {
      // Initialize call manager if not already done
      await callManager.initialize();

      // Start video call
      final callId = await callManager.startCall(
        recipientId: otherUserId,
        callType: CallType.video,
      );

      if (callId != null) {
        // Navigate to call screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CallScreen(
              callId: callId,
              isIncoming: false,
              otherUserId: otherUserId,
              otherUserName: otherUserName,
              otherUserProfilePicture: otherUserProfilePicture,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start video call')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting video call: $e')),
      );
    }
  }

  // Start audio call with user
  void _startAudioCall(Map<String, dynamic> user) async {
    final callManager = Provider.of<CallManager>(context, listen: false);
    final otherUserId = user['uid'];
    final otherUserName = user['name'] ?? 'User';
    final otherUserProfilePicture = user['profilePictureUrl'];

    if (otherUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to start call: User ID not found')),
      );
      return;
    }

    try {
      // Initialize call manager if not already done
      await callManager.initialize();

      // Start audio call
      final callId = await callManager.startCall(
        recipientId: otherUserId,
        callType: CallType.audio,
      );

      if (callId != null) {
        // Navigate to call screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CallScreen(
              callId: callId,
              isIncoming: false,
              otherUserId: otherUserId,
              otherUserName: otherUserName,
              otherUserProfilePicture: otherUserProfilePicture,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start audio call')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting audio call: $e')),
      );
    }
  }
}
