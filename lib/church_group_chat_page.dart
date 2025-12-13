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

class ChurchGroupChatPage extends StatefulWidget {
  final String churchId;
  final String churchName;

  const ChurchGroupChatPage({
    super.key,
    required this.churchId,
    required this.churchName,
  });

  @override
  State<ChurchGroupChatPage> createState() => _ChurchGroupChatPageState();
}

class _ChurchGroupChatPageState extends State<ChurchGroupChatPage> {
  final SupabaseChatService _chatService = SupabaseChatService();
  final UserService _userService = UserService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Media
  final ImagePicker _imagePicker = ImagePicker();

  // State variables
  bool _showEmojiPicker = false;
  bool _hasShownTooltip = false; // Track if tooltip has been shown
  int _tooltipShownCount = 0; // Track how many times tooltip has been shown

  String? _currentlyPlayingVoiceUrl;
  bool _isPlayingVoice = false;



  @override
  void initState() {
    super.initState();
    _ensureChurchGroupExists();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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

  Future<void> _ensureChurchGroupExists() async {
    print('DEBUG: _ensureChurchGroupExists called for church: ${widget.churchId}');
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        print('DEBUG: No current user in _ensureChurchGroupExists');
        return;
      }
      print('DEBUG: Current user: ${currentUser.id}');

      // Check if group already exists
      final existingGroup = await _supabase
          .from('groups')
          .select()
          .eq('group_id', widget.churchId)
          .maybeSingle();
      print('DEBUG: Existing group check result: $existingGroup');

      if (existingGroup == null) {
        print('DEBUG: Creating new church group');
        // Create the church group
        await _supabase.from('groups').insert({
          'group_id': widget.churchId,
          'group_name': widget.churchName,
          'group_type': 'church',
          'created_by': currentUser.id,
          'participants': [currentUser.id],
        });
        print('DEBUG: Church group created successfully');
      } else {
        // Ensure current user is a participant
        final participants = List<String>.from(existingGroup['participants'] ?? []);
        print('DEBUG: Existing participants: $participants');
        if (!participants.contains(currentUser.id)) {
          print('DEBUG: Adding current user to participants');
          participants.add(currentUser.id);
          await _supabase.from('groups').update({
            'participants': participants,
          }).eq('group_id', widget.churchId);
          print('DEBUG: User added to group participants');
        } else {
          print('DEBUG: User already in participants');
        }
      }
    } catch (e) {
      print('DEBUG: Error ensuring church group exists: $e');
    }
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      await _chatService.sendGroupMessage(
        groupId: widget.churchId,
        message: message,
        groupType: 'church',
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.churchName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            FutureBuilder<int>(
              future: _getMemberCount(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    '${snapshot.data} members',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  );
                }
                return const Text(
                  'Loading...',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showChurchInfo(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.getGroupMessages(widget.churchId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                print('DEBUG: StreamBuilder received ${messages.length} messages');
                for (var msg in messages) {
                  print('DEBUG: Message: type=${msg['message_type']}, media_url=${msg['media_url']}, message=${msg['message']}');
                }

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                        'No messages yet. Be the first to start the conversation!'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index];
                    final isCurrentUser =
                        messageData['sender_id'] == _supabase.auth.currentUser?.id;

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
                        setState(() {
                          _showEmojiPicker = !_showEmojiPicker;
                        });
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
                        maxLines: null,
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

  Widget _buildMessageBubble(
      Map<String, dynamic> messageData, bool isCurrentUser) {
    final messageType = messageData['message_type'] ?? 'text';
    final messageId = messageData['id'];

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
              child: messageContent,
            ),
          ),
          GestureDetector(
            onTap: () {
              // Handle emoji reaction tap here
            },
            child: Icon(
              Icons.emoji_emotions,
              color: Colors.orange,
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
      await _chatService.addGroupMessageReaction(messageId, reactionType);
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
      await _chatService.addGroupMessageReaction(messageId, reactionType);
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

  Future<int> _getMemberCount() async {
     try {
       final response = await _supabase
           .from('church_members')
           .select('id')
           .eq('church_id', widget.churchId);

       return (response as List).length;
     } catch (e) {
       return 0;
     }
   }

  void _showChurchInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.churchName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<int>(
              future: _getMemberCount(),
              builder: (context, snapshot) {
                return Text('Members: ${snapshot.data ?? 0}');
              },
            ),
            const SizedBox(height: 8),
            const Text(
                'This is your church group chat where all members can communicate.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _playVoiceMessage(String mediaUrl) {
    // stub with audio logic
  }

  // Image picker
  Future<void> _pickImage() async {
    try {
      final XFile? image =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
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
      if (video != null) {
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
    print('DEBUG: _sendImageMessage called with file: ${imageFile.path}');
    try {
      await _chatService.sendGroupImageMessage(
        groupId: widget.churchId,
        imageFile: imageFile,
        groupType: 'church',
      );
      print('DEBUG: _sendImageMessage completed successfully');
    } catch (e) {
      print('DEBUG: Error in _sendImageMessage: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending image: $e')),
      );
    }
  }

  // Send video message
  Future<void> _sendVideoMessage(XFile videoFile) async {
    try {
      await _chatService.sendGroupVideoMessage(
        groupId: widget.churchId,
        videoFile: videoFile,
        groupType: 'church',
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
    final mediaUrl = messageData['media_url'] as String?;
    final message = messageData['message'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mediaUrl != null)
          GestureDetector(
            onTap: () => _showFullScreenImage(mediaUrl),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.6,
                maxHeight: 200,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color:
                    isCurrentUser ? const Color(0xFF1E3A8A) : Colors.grey[300],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  mediaUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },
                ),
              ),
            ),
          ),
        if (message != null && message.isNotEmpty && message != '📷 Image')
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

  // Enhanced message bubble dispatcher
  Widget _buildMessageBubbleEnhanced(
      Map<String, dynamic> messageData, bool isCurrentUser) {
    final messageType = messageData['message_type'] ?? 'text';

    switch (messageType) {
      case 'text':
        return _buildTextMessageBubble(messageData, isCurrentUser);
      case 'image':
        return _buildImageMessageBubble(messageData, isCurrentUser);
      case 'video':
        return _buildVideoMessageBubble(messageData, isCurrentUser);
      case 'emoji':
        return _buildEmojiMessageBubble(messageData, isCurrentUser);
      default:
        return _buildTextMessageBubble(messageData, isCurrentUser);
    }
  }

  // Text message bubble
  Widget _buildTextMessageBubble(
      Map<String, dynamic> messageData, bool isCurrentUser) {
    final message = messageData['message'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isCurrentUser ? Colors.white : Colors.black,
          fontSize: 16,
        ),
      ),
    );
  }


  // Image message bubble
  Widget _buildImageMessageBubble(
      Map<String, dynamic> messageData, bool isCurrentUser) {
    final mediaUrl = messageData['media_url'] as String?;
    final message = messageData['message'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mediaUrl != null)
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.6,
              maxHeight: 200,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isCurrentUser ? const Color(0xFF1E3A8A) : Colors.grey[300],
              border: Border.all(
                color: isCurrentUser ? Colors.white24 : Colors.grey[400]!,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
        if (message != null && message.isNotEmpty && message != '📷 Image')
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

  // Video message bubble
  Widget _buildVideoMessageBubble(
      Map<String, dynamic> messageData, bool isCurrentUser) {
    final mediaUrl = messageData['media_url'] as String?;
    final message = messageData['message'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mediaUrl != null)
          Container(
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

  // Emoji message bubble
  Widget _buildEmojiMessageBubble(
      Map<String, dynamic> messageData, bool isCurrentUser) {
    final message = messageData['message'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isCurrentUser ? Colors.white : Colors.black,
          fontSize: 32, // Larger font for emojis
        ),
      ),
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
