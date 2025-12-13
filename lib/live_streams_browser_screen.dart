import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/live_stream_service.dart';
import 'live_stream_viewer_screen.dart';

class LiveStreamsBrowserScreen extends StatefulWidget {
  const LiveStreamsBrowserScreen({super.key});

  @override
  State<LiveStreamsBrowserScreen> createState() => _LiveStreamsBrowserScreenState();
}

class _LiveStreamsBrowserScreenState extends State<LiveStreamsBrowserScreen> {
  final LiveStreamService _liveStreamService = LiveStreamService();
  List<Map<String, dynamic>> _activeStreams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveStreams();
  }

  @override
  void dispose() {
    _liveStreamService.dispose();
    super.dispose();
  }

  Future<void> _loadActiveStreams() async {
    try {
      final streams = await _liveStreamService.getActiveStreams();
      if (mounted) {
        setState(() {
          _activeStreams = streams;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading streams: $e')),
        );
      }
    }
  }

  Future<void> _refreshStreams() async {
    setState(() => _isLoading = true);
    await _loadActiveStreams();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Streams'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStreams,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeStreams.isEmpty
              ? _buildEmptyState()
              : _buildStreamsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.live_tv,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Live Streams',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for live streams',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshStreams,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamsList() {
    return RefreshIndicator(
      onRefresh: _refreshStreams,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activeStreams.length,
        itemBuilder: (context, index) {
          final stream = _activeStreams[index];
          return _buildStreamCard(stream);
        },
      ),
    );
  }

  Widget _buildStreamCard(Map<String, dynamic> stream) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _joinStream(stream),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stream thumbnail/preview area
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Stack(
                children: [
                  // Placeholder for stream preview
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.live_tv,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stream info overlay
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.remove_red_eye,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${stream['viewer_count'] ?? 0} watching',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _getTimeAgo(stream['started_at']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stream details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[300],
                        child: Text(
                          (stream['broadcaster_name'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stream['broadcaster_name'] ?? 'Unknown Broadcaster',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Audience: ${stream['audience'] ?? 'Unknown'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _joinStream(stream),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Watch Live'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _joinStream(Map<String, dynamic> stream) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LiveStreamViewerScreen(
          streamId: stream['id'],
        ),
      ),
    );
  }

  String _getTimeAgo(String? startedAt) {
    if (startedAt == null) return '';

    try {
      final startTime = DateTime.parse(startedAt);
      final now = DateTime.now();
      final difference = now.difference(startTime);

      if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just started';
      }
    } catch (e) {
      return '';
    }
  }
}