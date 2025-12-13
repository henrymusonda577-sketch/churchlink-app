import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/live_stream_service.dart';

class LiveStreamViewerScreen extends StatefulWidget {
  final String streamId;

  const LiveStreamViewerScreen({
    super.key,
    required this.streamId,
  });

  @override
  State<LiveStreamViewerScreen> createState() => _LiveStreamViewerScreenState();
}

class _LiveStreamViewerScreenState extends State<LiveStreamViewerScreen> {
  final LiveStreamService _liveStreamService = LiveStreamService();
  final TextEditingController _chatController = TextEditingController();

  Map<String, dynamic>? _streamInfo;
  bool _isLoading = true;
  bool _isWatching = false;
  int _viewerCount = 0;
  List<Map<String, dynamic>> _chatMessages = [];
  webrtc.RTCVideoRenderer? _remoteRenderer;

  @override
  void initState() {
    super.initState();
    _initializeRenderer();
    _loadStreamInfo();
    _setupStreamListeners();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _remoteRenderer?.dispose();
    if (_isWatching) {
      _leaveStream();
    }
    _liveStreamService.dispose();
    super.dispose();
  }

  Future<void> _initializeRenderer() async {
    _remoteRenderer = webrtc.RTCVideoRenderer();
    await _remoteRenderer?.initialize();
  }

  void _setupStreamListeners() {
    // Listen for viewer count updates
    _liveStreamService.viewerCountStream.listen((count) {
      if (mounted) {
        setState(() => _viewerCount = count);
      }
    });

    // Listen for stream status updates
    _liveStreamService.streamStatusStream.listen((status) {
      if (mounted && status['status'] == 'ended') {
        _showStreamEndedDialog();
      }
    });

    // Listen for chat messages
    _liveStreamService.chatMessagesStream.listen((message) {
      if (mounted) {
        setState(() {
          _chatMessages.add(message);
        });
      }
    });
  }

  Future<void> _loadStreamInfo() async {
    try {
      final streamInfo = await _liveStreamService.getStreamInfo(widget.streamId);
      if (mounted) {
        setState(() {
          _streamInfo = streamInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stream: $e')),
        );
      }
    }
  }

  Future<void> _joinStream() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to watch streams')),
      );
      return;
    }

    try {
      final success = await _liveStreamService.joinStream(
        widget.streamId,
        currentUser.id,
        currentUser.userMetadata?['name'] ?? 'Anonymous',
      );

      if (success) {
        setState(() => _isWatching = true);

        // Set up remote video renderer
        if (_liveStreamService.remoteStream != null) {
          _remoteRenderer?.srcObject = _liveStreamService.remoteStream;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to join stream')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining stream: $e')),
      );
    }
  }

  Future<void> _leaveStream() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      await _liveStreamService.leaveStream(widget.streamId, currentUser.id);
    }
    setState(() => _isWatching = false);
  }

  void _showStreamEndedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Stream Ended'),
        content: const Text('The live stream has ended.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendChatMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    await _liveStreamService.sendChatMessage(
      widget.streamId,
      currentUser.id,
      currentUser.userMetadata?['name'] ?? 'Anonymous',
      message,
    );

    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Stream...'),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_streamInfo == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Stream Not Found'),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Stream not found or has ended'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Live: ${_streamInfo!['broadcaster_name'] ?? 'Unknown'}'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (_isWatching) {
              await _leaveStream();
            }
            Navigator.of(context).pop();
          },
        ),
        actions: [
          if (_streamInfo!['status'] == 'active')
            ElevatedButton(
              onPressed: _isWatching ? _leaveStream : _joinStream,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isWatching ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(_isWatching ? 'Leave' : 'Join'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Video area
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: Stack(
                children: [
                  // Video display
                  if (_isWatching && _remoteRenderer != null)
                    webrtc.RTCVideoView(
                      _remoteRenderer!,
                      objectFit: webrtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.live_tv,
                            size: 64,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isWatching ? 'Connecting...' : 'Join the stream to watch',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Live indicator
                  if (_streamInfo!['status'] == 'active')
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Stream info overlay
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Broadcaster: ${_streamInfo!['broadcaster_name'] ?? 'Unknown'}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Audience: ${_streamInfo!['audience'] ?? 'Unknown'}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Viewers: $_viewerCount',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Chat section
          Container(
            height: 300,
            color: Colors.grey[100],
            child: Column(
              children: [
                // Chat header
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.chat, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Live Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat messages
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final message = _chatMessages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${message['user_name'] ?? 'User'}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            Expanded(
                              child: Text(message['message'] ?? ''),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Chat input
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onSubmitted: (_) => _sendChatMessage(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF1E3A8A)),
                        onPressed: _sendChatMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}