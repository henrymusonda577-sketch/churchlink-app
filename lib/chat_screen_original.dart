import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'dart:io';
import 'dart:async';
import 'services/firebase_chat_service.dart';
import 'services/user_service.dart';
import 'discover_people_screen.dart';
import 'widgets/online_status_indicator.dart';

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
                      child: OnlineStatusIndicator(
                        userId: user['uid'] ?? _auth.currentUser?.uid ?? '',
                        size: 10,
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
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Video call coming soon!')),
                        );
                      },
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
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getMessages(otherUserId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final msg =
                              docs[index].data() as Map<String, dynamic>;
                          final fromMe = msg['from'] == _auth.currentUser?.uid;
                          return Align(
                            alignment: fromMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 2, horizontal: 8),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: fromMe
                                    ? const Color(0xFF1E3A8A)
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                msg['message'] ?? '',
                                style: TextStyle(
                                  color: fromMe ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
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
                            onPressed: () =>
                                _showAttachmentOptions(otherUserId),
                            tooltip: 'Attach file',
                          ),
                          IconButton(
                            icon: const Icon(Icons.image, color: Colors.grey),
                            onPressed: () => _pickImage(otherUserId),
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
                                    maxLines: null,
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

                      // Emoji picker
                      if (_showEmojiPicker)
                        SizedBox(
                          height: 250,
                          child: EmojiPicker(
                            onEmojiSelected: (category, emoji) {
                              _messageController.text += emoji.emoji;
                              _messageController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: _messageController.text.length),
                              );
                            },
                            config: const Config(
                              columns: 7,
                              emojiSizeMax: 32,
                              verticalSpacing: 0,
                              horizontalSpacing: 0,
                              gridPadding: EdgeInsets.zero,
                              initCategory: Category.RECENT,
                              bgColor: Color(0xFFF2F2F2),
                              indicatorColor: Color(0xFF1E3A8A),
                              iconColor: Colors.grey,
                              iconColorSelected: Color(0xFF1E3A8A),
                              backspaceColor: Color(0xFF1E3A8A),
                              skinToneDialogBgColor: Colors.white,
                              skinToneIndicatorColor: Colors.grey,
                              enableSkinTones: true,
                              recentTabBehavior: RecentTabBehavior.RECENT,
                              recentsLimit: 28,
                              replaceEmojiOnLimitExceed: false,
                              noRecents: Text(
                                'No Recents',
                                style: TextStyle(
                                    fontSize: 20, color: Colors.black26),
                                textAlign: TextAlign.center,
                              ),
                              loadingIndicator: SizedBox.shrink(),
                              tabIndicatorAnimDuration: kTabScrollDuration,
                              categoryIcons: CategoryIcons(),
                              buttonMode: ButtonMode.MATERIAL,
                            ),
                          ),
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
                _showFeatureDialog(
                    'Audio Call', 'Audio calling feature coming soon');
              },
              child: const Text('Audio Call'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showFeatureDialog(
                    'Video Call', 'Video calling feature coming soon');
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
      await _chatService.sendMessage(
        toUserId: otherUserId,
        message: message,
      );
      _messageController.clear();

      // Scroll to bottom after sending message
      Future.delayed(const Duration(milliseconds: 100), () {
        // Note: Scroll functionality would need to be implemented in the message list
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  // Attachment options
  void _showAttachmentOptions(String otherUserId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Send Image'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(otherUserId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Send Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(otherUserId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Send Document'),
              onTap: () {
                Navigator.pop(context);
                _pickDocument(otherUserId);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Image picker
  Future<void> _pickImage(String otherUserId) async {
    try {
      final XFile? image =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final File imageFile = File(image.path);
        await _sendImageMessage(otherUserId, imageFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Video picker
  Future<void> _pickVideo(String otherUserId) async {
    try {
      final XFile? video =
          await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        final File videoFile = File(video.path);
        await _sendVideoMessage(otherUserId, videoFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking video: $e')),
      );
    }
  }

  // Document picker
  Future<void> _pickDocument(String otherUserId) async {
    // TODO: Implement document picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document sharing coming soon!')),
    );
  }

  // Send image message
  Future<void> _sendImageMessage(String otherUserId, File imageFile) async {
    try {
      await _chatService.sendImageMessage(
        toUserId: otherUserId,
        imageFile: imageFile,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending image: $e')),
      );
    }
  }

  // Send video message
  Future<void> _sendVideoMessage(String otherUserId, File videoFile) async {
    try {
      await _chatService.sendVideoMessage(
        toUserId: otherUserId,
        videoFile: videoFile,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending video: $e')),
      );
    }
  }
}
