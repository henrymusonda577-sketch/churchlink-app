import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class LiveStreamService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = Uuid();

  // Broadcaster side
  webrtc.RTCPeerConnection? _broadcasterPeerConnection;
  webrtc.MediaStream? _localStream;
  String? _currentStreamId;
  bool _isBroadcasting = false;

  // Viewer side
  webrtc.RTCPeerConnection? _viewerPeerConnection;
  webrtc.MediaStream? _remoteStream;

  final _viewerCountController = StreamController<int>.broadcast();
  final _streamStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessagesController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<int> get viewerCountStream => _viewerCountController.stream;
  Stream<Map<String, dynamic>> get streamStatusStream => _streamStatusController.stream;
  Stream<Map<String, dynamic>> get chatMessagesStream => _chatMessagesController.stream;

  // WebRTC configuration
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': 'turn:turn.anyfirewall.com:443?transport=tcp',
        'username': 'webrtc',
        'credential': 'webrtc'
      }
    ]
  };

  // Start broadcasting a live stream
  Future<String?> startBroadcast({
    required String userId,
    required String userName,
    required String audience,
    required String churchId,
  }) async {
    try {
      // Request permissions
      await _requestPermissions();

      // Generate stream ID
      _currentStreamId = 'stream_${_uuid.v4()}';

      // Initialize local media stream
      _localStream = await webrtc.navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });

      // Create peer connection for broadcasting
      _broadcasterPeerConnection = await webrtc.createPeerConnection(_configuration, {});

      // Add local stream tracks
      _localStream!.getTracks().forEach((track) {
        _broadcasterPeerConnection!.addTrack(track, _localStream!);
      });

      // Create stream document in Supabase
      await _supabase.from('live_streams').insert({
        'id': _currentStreamId,
        'broadcaster_id': userId,
        'broadcaster_name': userName,
        'audience': audience,
        'church_id': churchId,
        'status': 'active',
        'viewer_count': 0,
        'started_at': DateTime.now().toIso8601String(),
        'stream_data': {
          'type': 'webrtc_broadcast',
          'configuration': _configuration,
        }
      });

      _isBroadcasting = true;

      // Start listening for viewers
      _listenForViewers();

      // Update stream status
      _streamStatusController.add({
        'status': 'active',
        'streamId': _currentStreamId,
        'isBroadcasting': true,
      });

      return _currentStreamId;
    } catch (e) {
      print('Error starting broadcast: $e');
      await stopBroadcast();
      return null;
    }
  }

  // Stop broadcasting
  Future<void> stopBroadcast() async {
    try {
      _isBroadcasting = false;

      // Close peer connection
      await _broadcasterPeerConnection?.close();
      _broadcasterPeerConnection = null;

      // Stop local stream
      _localStream?.getTracks().forEach((track) => track.stop());
      _localStream = null;

      // Update stream status in database
      if (_currentStreamId != null) {
        await _supabase.from('live_streams').update({
          'status': 'ended',
          'ended_at': DateTime.now().toIso8601String(),
        }).eq('id', _currentStreamId!);
      }

      _streamStatusController.add({
        'status': 'ended',
        'isBroadcasting': false,
      });

      _currentStreamId = null;
    } catch (e) {
      print('Error stopping broadcast: $e');
    }
  }

  // Join a live stream as viewer
  Future<bool> joinStream(String streamId, String viewerId, String viewerName) async {
    try {
      // Get stream info
      final streamData = await _supabase
          .from('live_streams')
          .select('*')
          .eq('id', streamId)
          .eq('status', 'active')
          .single();

      if (streamData == null) return false;

      // Create viewer peer connection
      _viewerPeerConnection = await webrtc.createPeerConnection(_configuration, {});

      // Listen for remote stream
      _viewerPeerConnection!.onTrack = (webrtc.RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
        }
      };

      // Add viewer to stream
      await _supabase.from('stream_viewers').insert({
        'stream_id': streamId,
        'viewer_id': viewerId,
        'viewer_name': viewerName,
        'joined_at': DateTime.now().toIso8601String(),
      });

      // Update viewer count
      await _updateViewerCount(streamId);

      // Listen for stream updates
      _listenForStreamUpdates(streamId);

      return true;
    } catch (e) {
      print('Error joining stream: $e');
      return false;
    }
  }

  // Leave stream as viewer
  Future<void> leaveStream(String streamId, String viewerId) async {
    try {
      await _viewerPeerConnection?.close();
      _viewerPeerConnection = null;

      _remoteStream?.getTracks().forEach((track) => track.stop());
      _remoteStream = null;

      // Remove viewer from database
      await _supabase
          .from('stream_viewers')
          .delete()
          .eq('stream_id', streamId)
          .eq('viewer_id', viewerId);

      // Update viewer count
      await _updateViewerCount(streamId);
    } catch (e) {
      print('Error leaving stream: $e');
    }
  }

  // Send chat message
  Future<void> sendChatMessage(String streamId, String userId, String userName, String message) async {
    try {
      await _supabase.from('stream_chat').insert({
        'stream_id': streamId,
        'user_id': userId,
        'user_name': userName,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error sending chat message: $e');
    }
  }

  // Get active streams
  Future<List<Map<String, dynamic>>> getActiveStreams() async {
    try {
      final now = DateTime.now();
      // Only show streams from the last 24 hours to avoid stale streams
      final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));

      final streams = await _supabase
          .from('live_streams')
          .select('*')
          .eq('status', 'active')
          .gte('started_at', twentyFourHoursAgo.toIso8601String())
          .order('started_at', ascending: false);

      // Additional client-side filtering to ensure streams are truly active
      final filteredStreams = List<Map<String, dynamic>>.from(streams).where((stream) {
        final startedAt = DateTime.parse(stream['started_at']);
        final timeSinceStart = now.difference(startedAt);

        // Filter out streams that have been running for more than 12 hours
        // This handles cases where streams weren't properly ended
        return timeSinceStart.inHours < 12;
      }).toList();

      return filteredStreams;
    } catch (e) {
      print('Error getting active streams: $e');
      return [];
    }
  }

  // Get stream info
  Future<Map<String, dynamic>?> getStreamInfo(String streamId) async {
    try {
      final stream = await _supabase
          .from('live_streams')
          .select('*')
          .eq('id', streamId)
          .single();

      return stream;
    } catch (e) {
      print('Error getting stream info: $e');
      return null;
    }
  }

  // Private methods
  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final microphoneStatus = await Permission.microphone.request();

    if (!cameraStatus.isGranted || !microphoneStatus.isGranted) {
      throw Exception('Camera and microphone permissions required for live streaming');
    }
  }

  void _listenForViewers() {
    if (_currentStreamId == null) return;

    _supabase
        .from('stream_viewers')
        .stream(primaryKey: ['id'])
        .eq('stream_id', _currentStreamId!)
        .listen((viewers) {
          _viewerCountController.add(viewers.length);
        });
  }

  void _listenForStreamUpdates(String streamId) {
    // Listen for chat messages
    _supabase
        .from('stream_chat')
        .stream(primaryKey: ['id'])
        .eq('stream_id', streamId)
        .order('timestamp', ascending: false)
        .listen((messages) {
          for (final message in messages) {
            _chatMessagesController.add(message);
          }
        });

    // Listen for stream status changes
    _supabase
        .from('live_streams')
        .stream(primaryKey: ['id'])
        .eq('id', streamId)
        .listen((streams) {
          if (streams.isNotEmpty) {
            final stream = streams.first;
            _streamStatusController.add({
              'status': stream['status'],
              'viewerCount': stream['viewer_count'] ?? 0,
            });
          }
        });
  }

  Future<void> _updateViewerCount(String streamId) async {
    try {
      final viewers = await _supabase
          .from('stream_viewers')
          .select('id')
          .eq('stream_id', streamId);

      final count = viewers.length;

      await _supabase
          .from('live_streams')
          .update({'viewer_count': count})
          .eq('id', streamId);

      _viewerCountController.add(count);
    } catch (e) {
      print('Error updating viewer count: $e');
    }
  }

  // Getters
  webrtc.MediaStream? get localStream => _localStream;
  webrtc.MediaStream? get remoteStream => _remoteStream;
  bool get isBroadcasting => _isBroadcasting;
  String? get currentStreamId => _currentStreamId;

  // Cleanup
  void dispose() {
    stopBroadcast();
    _viewerPeerConnection?.close();
    _viewerPeerConnection = null;
    _remoteStream?.getTracks().forEach((track) => track.stop());
    _remoteStream = null;

    _viewerCountController.close();
    _streamStatusController.close();
    _chatMessagesController.close();
  }
}