import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/live_stream_service.dart';

class LiveStreamScreen extends StatefulWidget {
  final String audience;
  final String pastorName;
  final String churchId;

  const LiveStreamScreen({
    super.key,
    required this.audience,
    required this.pastorName,
    required this.churchId,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  final LiveStreamService _liveStreamService = LiveStreamService();
  final TextEditingController _chatController = TextEditingController();

  bool _isStreaming = false;
  bool _isPaused = false;
  int _viewerCount = 0;
  String? _streamId;
  List<Map<String, dynamic>> _chatMessages = [];
  webrtc.RTCVideoRenderer? _localRenderer;
  webrtc.RTCVideoRenderer? _remoteRenderer;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _setupStreamListeners();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
    _liveStreamService.dispose();
    super.dispose();
  }

  Future<void> _initializeRenderers() async {
    _localRenderer = webrtc.RTCVideoRenderer();
    _remoteRenderer = webrtc.RTCVideoRenderer();
    await _localRenderer?.initialize();
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
      if (mounted) {
        setState(() {
          _isStreaming = status['isBroadcasting'] ?? false;
          _streamId = status['streamId'];
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Stream - ${widget.audience}'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
            onPressed: _toggleStreaming,
          ),
        ],
      ),
      body: Column(
        children: [
          // Stream preview area
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: Stack(
                children: [
                  // Video display
                  if (_isStreaming && _localRenderer != null)
                    webrtc.RTCVideoView(
                      _localRenderer!,
                      objectFit: webrtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isStreaming
                                ? (_isPaused ? Icons.pause : Icons.videocam)
                                : Icons.videocam_off,
                            size: 64,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isStreaming
                                ? (_isPaused ? 'Stream Paused' : 'Live Streaming')
                                : 'Stream Not Started',
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
                  if (_isStreaming)
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
                            'Audience: ${widget.audience}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Pastor: ${widget.pastorName}',
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

          // Stream controls and chat
          Container(
            height: 300,
            color: Colors.grey[100],
            child: Column(
              children: [
                // Stream info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStreamInfo('Viewers', _viewerCount.toString()),
                      _buildStreamInfo('Duration', _getStreamDuration()),
                      _buildStreamInfo(
                          'Status', _isStreaming ? 'Live' : 'Offline'),
                    ],
                  ),
                ),

                // Control buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isStreaming ? null : _startStream,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Stream'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isStreaming ? _pauseStream : null,
                        icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                        label: Text(_isPaused ? 'Resume' : 'Pause'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isStreaming ? _stopStream : null,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop Stream'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Chat section
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamInfo(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  void _toggleStreaming() {
    if (_isStreaming) {
      _stopStream();
    } else {
      _startStream();
    }
  }

  Future<void> _startStream() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to start streaming')),
      );
      return;
    }

    try {
      final streamId = await _liveStreamService.startBroadcast(
        userId: currentUser.id,
        userName: widget.pastorName,
        audience: widget.audience,
        churchId: widget.churchId,
      );

      if (streamId != null) {
        // Set up local video renderer
        if (_liveStreamService.localStream != null) {
          _localRenderer?.srcObject = _liveStreamService.localStream;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Live stream started!'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start live stream'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting stream: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pauseStream() async {
    // For now, just pause locally - full pause/resume would need server-side support
    setState(() {
      _isPaused = !_isPaused;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isPaused ? 'Stream paused' : 'Stream resumed'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _stopStream() async {
    await _liveStreamService.stopBroadcast();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Live stream stopped'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getStreamDuration() {
    // This would need to track start time - for now return placeholder
    return '00:00';
  }

  Future<void> _sendChatMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty || _streamId == null) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    await _liveStreamService.sendChatMessage(
      _streamId!,
      currentUser.id,
      widget.pastorName,
      message,
    );

    _chatController.clear();
  }
}
