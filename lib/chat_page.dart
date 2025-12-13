import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import './services/supabase_chat_service.dart';
import './services/user_service.dart';

class ChatPage extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final SupabaseChatService _chatService = SupabaseChatService();
  final UserService _userService = UserService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Media
  final ImagePicker _imagePicker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();

  // State variables
  bool _showEmojiPicker = false;
  bool _isPlayingVoice = false;
  String? _currentlyPlayingVoiceUrl;

  // Recording state
  bool _isRecording = false;
  String? _recordingPath;
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlayingVoice = false;
        _currentlyPlayingVoiceUrl = null;
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      await _chatService.sendMessage(
        toUserId: widget.otherUserId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  _getAvatarLetter(widget.otherUserName),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.otherUserName,
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
              stream: _chatService.getMessages(widget.otherUserId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                if (messages.isEmpty) {
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
                      icon: const Icon(Icons.attach_file,
                          color: Colors.grey),
                      onPressed: _showAttachmentOptions,
                      tooltip: 'Attach file',
                    ),
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
                    IconButton(
                      icon: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: _isRecording ? Colors.red : Colors.grey,
                      ),
                      onPressed: () async {
                        if (_isRecording) {
                          await _stopRecording();
                        } else {
                          await _startRecording();
                        }
                      },
                      tooltip: _isRecording ? 'Stop Recording' : 'Record Voice',
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

  Widget _buildMessageBubble(
      Map<String, dynamic> messageData, bool isCurrentUser) {
    final messageType = messageData['messageType'] ?? 'text';

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
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
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser)
              FutureBuilder<Map<String, dynamic>?>(
                future: _userService.getUserById(messageData['sender_id']),
                builder: (context, userSnapshot) {
                  if (userSnapshot.hasData && userSnapshot.data != null) {
                    return Text(
                      userSnapshot.data!['name'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            isCurrentUser ? Colors.white70 : Colors.grey[600],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            // Display content based on message type
            if (messageType == 'voice')
              _buildVoiceMessageContent(messageData, isCurrentUser)
            else if (messageType == 'image')
              _buildImageMessageContent(messageData, isCurrentUser)
            else if (messageType == 'video')
              _buildVideoMessageContent(messageData, isCurrentUser)
            else
              // Default text message
              Text(
                messageData['message'] ?? '',
                style: TextStyle(
                  color: isCurrentUser ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(messageData['timestamp']),
              style: TextStyle(
                fontSize: 10,
                color: isCurrentUser ? Colors.white70 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
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


  // Attachment options
  void _showAttachmentOptions() {
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
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Send Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Send Document'),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
          ],
        ),
      ),
    );
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

  // Document picker
  Future<void> _pickDocument() async {
    // TODO: Implement document picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document sharing coming soon!')),
    );
  }

  // Send image message
  Future<void> _sendImageMessage(XFile imageFile) async {
    try {
      await _chatService.sendImageMessage(
        toUserId: widget.otherUserId,
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
    try {
      await _chatService.sendVideoMessage(
        toUserId: widget.otherUserId,
        videoFile: videoFile,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending video: $e')),
      );
    }
  }

  // Play voice message
  Future<void> _playVoiceMessage(String url) async {
    try {
      if (_currentlyPlayingVoiceUrl == url && _isPlayingVoice) {
        await _audioPlayer.pause();
        setState(() {
          _isPlayingVoice = false;
        });
      } else {
        await _audioPlayer.play(UrlSource(url));
        setState(() {
          _currentlyPlayingVoiceUrl = url;
          _isPlayingVoice = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing voice message: $e')),
      );
    }
  }

  // Build voice message content
  Widget _buildVoiceMessageContent(
      Map<String, dynamic> messageData, bool isCurrentUser) {
    final mediaUrl = messageData['mediaUrl'] as String?;
    final duration = messageData['voiceDuration'] as int? ?? 0;
    final isPlaying = _currentlyPlayingVoiceUrl == mediaUrl && _isPlayingVoice;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.white24 : Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: isCurrentUser ? Colors.white : Colors.blue,
            ),
            onPressed:
                mediaUrl != null ? () => _playVoiceMessage(mediaUrl) : null,
          ),
          const SizedBox(width: 8),
          const Icon(Icons.mic, size: 20),
          const SizedBox(width: 8),
          Text(
            'Voice ${duration}s',
            style: TextStyle(
              color: isCurrentUser ? Colors.white : Colors.black,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Build image message content
  Widget _buildImageMessageContent(
      Map<String, dynamic> messageData, bool isCurrentUser) {
    final mediaUrl = messageData['mediaUrl'] as String?;
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
    final mediaUrl = messageData['mediaUrl'] as String?;
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

  // Start voice recording
  Future<void> _startRecording() async {
    try {
      // Request microphone permission
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Microphone permission is required to record voice messages')),
        );
        return;
      }

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/voice_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording
      await _audioRecorder.start(const RecordConfig(), path: _recordingPath!);
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      // Start timer to track recording duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording started...')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  // Stop voice recording and send message
  Future<void> _stopRecording() async {
    try {
      // Stop recording
      await _audioRecorder.stop();
      _recordingTimer?.cancel();

      setState(() {
        _isRecording = false;
      });

      if (_recordingPath != null) {
        final audioFile = XFile(_recordingPath!);
        // Note: On web, checking exists might not work, but proceed
        await _sendVoiceMessage(audioFile);
      }

      // Clean up
      setState(() {
        _recordingPath = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $e')),
      );
    }
  }

  // Send voice message
  Future<void> _sendVoiceMessage(XFile audioFile) async {
    try {
      await _chatService.sendVoiceMessage(
        toUserId: widget.otherUserId,
        audioFile: audioFile,
        durationInSeconds: _recordingDuration,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice message sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending voice message: $e')),
      );
    }
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
