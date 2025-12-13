import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import './services/supabase_chat_service.dart';
import './services/user_service.dart';
import './widgets/tinder_swipe_card.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseChatService _chatService = SupabaseChatService();
  final UserService _userService = UserService();

  // Chat state variables
  String? _selectedUserId;
  String? _selectedUserName;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Media
  final ImagePicker _imagePicker = ImagePicker();

  // State variables
  bool _showEmojiPicker = false;
  int _tooltipShownCount = 0; // Track how many times tooltip has been shown




  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Conversations'),
            Tab(text: 'Chat'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showNewConversationDialog(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConversationsTab(),
          _buildChatTab(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.message, size: 80, color: Color(0xFF1E3A8A)),
          const SizedBox(height: 20),
          const Text(
            'No conversations yet',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Start connecting with your church community',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => _showNewConversationDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Start New Conversation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(
      Map<String, dynamic> conversation, String conversationId) {
    final participants = conversation['participants'] as List<dynamic>? ?? [];
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => null,
    );

    if (otherUserId == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUserInfo(otherUserId),
      builder: (context, userSnapshot) {
        final userInfo = userSnapshot.data ?? {};
        final userName =
            userInfo['name'] ?? userInfo['email'] ?? 'Unknown User';
        final profilePictureUrl = userInfo['profile_picture_url'] as String?;
        final lastMessage = conversation['last_message'] as String? ?? '';
        final lastMessageTime = conversation['last_message_timestamp'] as String?;
        final unreadCounts = conversation['unread_counts'] as Map<String, dynamic>? ?? {};
        final unreadCount = (unreadCounts[currentUserId] as int?) ?? 0;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF1E3A8A),
            backgroundImage: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                ? NetworkImage(profilePictureUrl)
                : null,
            child: (profilePictureUrl == null || profilePictureUrl.isEmpty)
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          title: Text(
            userName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (lastMessageTime != null)
                Text(
                  _formatTime(DateTime.parse(lastMessageTime)),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              if (unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A8A),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          onTap: () => _openChat(otherUserId, userName),
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  Future<Map<String, dynamic>?> _getUserInfo(String userId) async {
    try {
      // Try to get from Supabase first
      final supabaseUser = await Supabase.instance.client
          .from('users')
          .select('name, email, profile_picture_url')
          .eq('id', userId)
          .single();

      return {
        'name': supabaseUser['name'] ?? '',
        'email': supabaseUser['email'] ?? '',
        'profile_picture_url': supabaseUser['profile_picture_url'] ?? '',
      };
    } catch (e) {
      // Fallback to Firebase Auth if Supabase fails
      try {
        // This is a simplified approach - in a real app you'd cache user info
        return {
          'name': '',
          'email': 'user$userId@churchlink.com',
          'profile_picture_url': '',
        };
      } catch (e) {
        return null;
      }
    }
  }

  void _showNewConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => UserSearchDialog(
        userService: _userService,
        onUserSelected: (userId, userName) {
          Navigator.pop(context); // Close dialog
          _openChat(userId, userName); // Open chat
        },
      ),
    );
  }

  void _openChat(String otherUserId, String otherUserName) async {
    print('DEBUG: _openChat called with userId: $otherUserId, userName: $otherUserName');

    // Ensure chat exists before opening
    try {
      await _chatService.ensureChatExists(otherUserId);
      print('DEBUG: Chat ensured to exist for user: $otherUserId');
    } catch (e) {
      print('DEBUG: Error ensuring chat exists: $e');
      // Continue anyway, the chat will be created when sending the first message
    }

    if (mounted) {
      setState(() {
        _selectedUserId = otherUserId;
        _selectedUserName = otherUserName;
        print('DEBUG: Set selected user - ID: $_selectedUserId, Name: $_selectedUserName');
      });
      _tabController.animateTo(1); // Switch to chat tab
      print('DEBUG: Switched to chat tab');
    }
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

  void _sendMessage() async {
    if (_selectedUserId == null) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      await _chatService.sendMessage(
        toUserId: _selectedUserId!,
        message: message,
      );
      _messageController.clear();

      // Scroll to bottom after sending message
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }



  Widget _buildMessageBubble(
      Map<String, dynamic> messageData, bool isCurrentUser) {
    final messageType = messageData['message_type'] ?? 'text';
    final messageId = messageData['id'];
    print('DEBUG: messageType = $messageType for message ${messageData['id']}');

    Widget messageContent;
    switch (messageType) {
      case 'image':
        messageContent = _buildImageMessageContent(messageData, isCurrentUser);
        break;
      case 'video':
        messageContent = _buildVideoMessageContent(messageData, isCurrentUser);
        break;
      default:
        messageContent = Text(
          messageData['message'] ?? '',
          style: TextStyle(
            color: isCurrentUser ? Colors.white : Colors.black,
            fontSize: 16,
          ),
        );
    }

    final messageBubble = Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          !isCurrentUser ? const SizedBox(width: 40) : const SizedBox.shrink(), // Space for reaction emoji
          Flexible(
            child: Tooltip(
              message: !isCurrentUser && _tooltipShownCount < 3
                  ? 'Tap to react with emoji'
                  : '',
              onTriggered: () {
                if (!isCurrentUser && _tooltipShownCount < 3) {
                  setState(() {
                    _tooltipShownCount++;
                  });
                }
              },
              child: GestureDetector(
                onTap: !isCurrentUser ? () => _showReactionPicker(messageId) : null,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentUser ? const Color(0xFF1E3A8A) : Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isCurrentUser
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: isCurrentUser
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                    // Add subtle shadow for tappable messages
                    boxShadow: !isCurrentUser ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      )
                    ] : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      !isCurrentUser ? FutureBuilder<Map<String, dynamic>?>(
                        future: _userService.getUserById(messageData['sender_id']),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.hasData && userSnapshot.data != null) {
                            return Text(
                              userSnapshot.data!['name'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    isCurrentUser ? Colors.white.withOpacity(0.7) : Colors.grey[600],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ) : const SizedBox.shrink(),
                      // Display content based on message type
                      messageContent,
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(messageData['timestamp']),
                        style: TextStyle(
                          fontSize: 10,
                          color: isCurrentUser ? Colors.white.withOpacity(0.7) : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Only wrap with TinderSwipeCard for messages from other users (not current user)
    if (!isCurrentUser) {
      return TinderSwipeCard(
        child: messageBubble,
        onSwipeComplete: (direction) {
          _handleSwipeReaction(messageId, direction);
        },
      );
    }

    return messageBubble;
  }

  void _handleSwipeReaction(String messageId, SwipeDirection direction) {
    String reactionType;
    switch (direction) {
      case SwipeDirection.right:
        reactionType = 'love'; // Heart for right swipe
        break;
      case SwipeDirection.left:
        reactionType = 'dislike'; // Thumbs down for left swipe
        break;
      default:
        return; // No reaction for no swipe
    }

    // Add reaction to database
    _addSwipeReaction(messageId, reactionType);
  }

  Future<void> _addSwipeReaction(String messageId, String reactionType) async {
    try {
      await _chatService.addMessageReaction(messageId, reactionType);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reacted with $reactionType!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding reaction: $e')),
      );
    }
  }

  void _showReactionPicker(String messageId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'React to message',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildReactionButton(messageId, 'love', '❤️'),
                _buildReactionButton(messageId, 'dislike', '👎'),
                _buildReactionButton(messageId, 'laugh', '😂'),
                _buildReactionButton(messageId, 'angry', '😡'),
                _buildReactionButton(messageId, 'sad', '😢'),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButton(String messageId, String reactionType, String emoji) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // Close the bottom sheet
        _addTapReaction(messageId, reactionType);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  Future<void> _addTapReaction(String messageId, String reactionType) async {
    try {
      await _chatService.addMessageReaction(messageId, reactionType);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reacted with $reactionType!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding reaction: $e')),
      );
    }
  }

  String _formatTimestamp(String? timestamp) {
     if (timestamp == null) return '';

     final now = DateTime.now();
     final messageTime = DateTime.parse(timestamp);
     final difference = now.difference(messageTime);

    if (difference.inDays > 0) {
      return DateFormat('MMM d, h:mm a').format(messageTime);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildConversationsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getUserConversations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Error loading conversations'),
                const SizedBox(height: 8),
                Text(snapshot.error.toString(),
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final conversations = snapshot.data ?? [];

        if (conversations.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            return _buildConversationTile(
                conversation, conversation['chat_id']);
          },
        );
      },
    );
  }

  Widget _buildChatTab() {
    print('DEBUG: _buildChatTab called - selectedUserId: $_selectedUserId, selectedUserName: $_selectedUserName');

    if (_selectedUserId == null || _selectedUserName == null) {
      print('DEBUG: No user selected, showing selection prompt');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Select a conversation to start chatting',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Conversations'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    print('DEBUG: User selected, building chat interface for: $_selectedUserName');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            FutureBuilder<Map<String, dynamic>?>(
              future: _getUserInfo(_selectedUserId!),
              builder: (context, userSnapshot) {
                final userInfo = userSnapshot.data ?? {};
                final profilePictureUrl = userInfo['profile_picture_url'] as String?;

                return CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                      ? NetworkImage(profilePictureUrl)
                      : null,
                  child: (profilePictureUrl == null || profilePictureUrl.isEmpty)
                      ? Text(
                          _getAvatarLetter(_selectedUserName!),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        )
                      : null,
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedUserName!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.getMessages(_selectedUserId!),
              builder: (context, snapshot) {
                print('DEBUG: Chat StreamBuilder - connectionState: ${snapshot.connectionState}, hasError: ${snapshot.hasError}, hasData: ${snapshot.hasData}');

                if (snapshot.hasError) {
                  print('DEBUG: Chat StreamBuilder error: ${snapshot.error}');
                  return const Center(child: Text('Error loading messages'));
                }

                if (!snapshot.hasData) {
                  print('DEBUG: Chat StreamBuilder waiting for data');
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                print('DEBUG: Chat StreamBuilder received ${messages.length} messages');

                if (messages.isEmpty) {
                  print('DEBUG: No messages in chat, showing empty state');
                  return const Center(
                    child: Text(
                        'No messages yet. Start a conversation!'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index];
                    final isCurrentUser =
                        messageData['sender_id'] == Supabase.instance.client.auth.currentUser?.id;

                    return _buildMessageBubble(messageData, isCurrentUser);
                  },
                );
              },
            ),
          ),

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
                      icon: const Icon(Icons.image, color: Colors.grey),
                      onPressed: _pickImage,
                      tooltip: 'Send image',
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.emoji_emotions, color: Colors.grey),
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _showEmojiPicker = !_showEmojiPicker;
                          });
                        }
                      },
                      tooltip: 'Emoji',
                    ),

                    const SizedBox(width: 8),

                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Send button
                    CircleAvatar(
                      backgroundColor: const Color(0xFF1E3A8A),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
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
                          TextPosition(offset: _messageController.text.length),
                        );
                      },
                      config: const Config(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  // Image picker
  Future<void> _pickImage() async {
    try {
      final XFile? image =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null && _selectedUserId != null) {
        await _sendImageMessage(image);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Video picker
  Future<void> _pickVideo() async {
    try {
      final XFile? video =
          await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (video != null && _selectedUserId != null) {
        await _sendVideoMessage(video);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking video: $e')),
      );
    }
  }



  // Send image message
  Future<void> _sendImageMessage(XFile imageFile) async {
    if (_selectedUserId == null) return;

    try {
      await _chatService.sendImageMessage(
        toUserId: _selectedUserId!,
        imageFile: imageFile,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending image: $e')),
      );
    }
  }

  // Send video message
  Future<void> _sendVideoMessage(XFile videoFile) async {
    if (_selectedUserId == null) return;

    try {
      await _chatService.sendVideoMessage(
        toUserId: _selectedUserId!,
        videoFile: videoFile,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending video: $e')),
      );
    }
  }



  // Build image message content
  Widget _buildImageMessageContent(
      Map<String, dynamic> messageData, bool isCurrentUser) {
    print('DEBUG: _buildImageMessageContent called for message: ${messageData['id']}');
    print('DEBUG: messageData keys: ${messageData.keys}');
    print('DEBUG: messageData: $messageData');
    final mediaUrl = messageData['media_url'] as String?;
    final message = messageData['message'] as String?;

    // Extract filename from Supabase URL for proxy
    String? proxyUrl;
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      // Extract filename from Supabase storage URL
      final uri = Uri.parse(mediaUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 2 && pathSegments[pathSegments.length - 2] == 'chat-media') {
        final fileName = pathSegments.last;
        proxyUrl = 'http://localhost:3001/chat-image/$fileName';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (proxyUrl != null && proxyUrl.isNotEmpty)
          GestureDetector(
            onTap: () => _showFullScreenImage(proxyUrl!),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
                maxHeight: 250,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isCurrentUser ? Colors.white.withOpacity(0.1) : Colors.grey[100],
                border: Border.all(
                  color: isCurrentUser ? Colors.white.withOpacity(0.2) : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(
                      proxyUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: double.infinity,
                          height: 150,
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('DEBUG: Image load error: $error');
                        return Container(
                          width: double.infinity,
                          height: 150,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image, color: Colors.grey, size: 40),
                                SizedBox(height: 8),
                                Text('Image failed to load', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Build video message content
  Widget _buildVideoMessageContent(
      Map<String, dynamic> messageData, bool isCurrentUser) {
    final mediaUrl = messageData['media_url'] as String?;
    final message = messageData['message'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mediaUrl != null)
          GestureDetector(
            onTap: () => _showFullScreenVideo(mediaUrl),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.6,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrentUser ? Colors.white24 : Colors.grey[400]!,
                  width: 1,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ),
        if (message != null && message.isNotEmpty && message != '🎥 Video')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              message,
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
          ),
      ],
    );
  }

  // Show full screen image
  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
              );
            },
          ),
        ),
      ),
    );
  }

  // Show full screen video
  void _showFullScreenVideo(String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: VideoPlayerWidget(videoUrl: videoUrl),
      ),
    );
  }



}

class UserSearchDialog extends StatefulWidget {
  const UserSearchDialog({
    super.key,
    required this.userService,
    required this.onUserSelected,
  });

  final UserService userService;
  final Function(String, String) onUserSelected;

  @override
  State<UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends State<UserSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _defaultUsers = [];
  bool _isSearching = false;
  bool _isLoadingDefault = true;

  @override
  void initState() {
    super.initState();
    _loadDefaultUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultUsers() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final response = await Supabase.instance.client
          .from('users')
          .select('id, name, email, profile_picture_url')
          .neq('id', currentUserId)
          .limit(50); // Limit to prevent loading too many users

      setState(() {
        _defaultUsers = List<Map<String, dynamic>>.from(response);
        _isLoadingDefault = false;
      });
    } catch (e) {
      print('Error loading default users: $e');
      setState(() {
        _isLoadingDefault = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final response = await Supabase.instance.client
          .from('users')
          .select('id, name, email, profile_picture_url')
          .or('name.ilike.%${query}%,email.ilike.%${query}%')
          .neq('id', currentUserId)
          .limit(20);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(response);
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start New Conversation'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _searchUsers,
            ),
            const SizedBox(height: 16),
            if (_isSearching)
              const CircularProgressIndicator()
            else if (_searchController.text.isNotEmpty &&
                _searchResults.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    final userName = user['name'] ?? '';
                    final userEmail = user['email'] ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1E3A8A),
                        backgroundImage: user['profile_picture_url'] != null && user['profile_picture_url'].isNotEmpty
                            ? NetworkImage(user['profile_picture_url'])
                            : null,
                        child: (user['profile_picture_url'] == null || user['profile_picture_url'].isEmpty)
                            ? Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Text(userName.isNotEmpty ? userName : userEmail),
                      subtitle: userName.isNotEmpty ? Text(userEmail) : null,
                      onTap: () {
                        Navigator.pop(context);
                        _openChat(user['id'],
                            userName.isNotEmpty ? userName : userEmail);
                      },
                    );
                  },
                ),
              )
            else if (_searchController.text.isNotEmpty)
              const Text('No users found')
            else if (_isLoadingDefault)
              const CircularProgressIndicator()
            else if (_defaultUsers.isNotEmpty)
              SizedBox(
                height: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'People on the app',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _defaultUsers.length,
                        itemBuilder: (context, index) {
                          final user = _defaultUsers[index];
                          final userName = user['name'] ?? '';
                          final userEmail = user['email'] ?? '';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF1E3A8A),
                              backgroundImage: user['profile_picture_url'] != null && user['profile_picture_url'].isNotEmpty
                                  ? NetworkImage(user['profile_picture_url'])
                                  : null,
                              child: (user['profile_picture_url'] == null || user['profile_picture_url'].isEmpty)
                                  ? Text(
                                      userName.isNotEmpty
                                          ? userName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                                userName.isNotEmpty ? userName : userEmail),
                            subtitle:
                                userName.isNotEmpty ? Text(userEmail) : null,
                            onTap: () {
                              Navigator.pop(context);
                              _openChat(user['id'],
                                  userName.isNotEmpty ? userName : userEmail);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text('No people available to chat with'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  void _openChat(String otherUserId, String otherUserName) {
    widget.onUserSelected(otherUserId, otherUserName);
  }
}

// Video player widget for full screen
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late vp.VideoPlayerController _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = vp.VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
      });
    _controller.addListener(() {
      setState(() {
        _isPlaying = _controller.value.isPlaying;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    vp.VideoPlayer(_controller),
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 50,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPlaying ? _controller.pause() : _controller.play();
                        });
                      },
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(Icons.close),
      ),
    );
  }
}