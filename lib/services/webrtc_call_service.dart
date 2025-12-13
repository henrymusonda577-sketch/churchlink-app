import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:permission_handler/permission_handler.dart';
import 'webrtc_signaling_service.dart';

class WebRTCCallService {
  final WebRTCSignalingService _signalingService = WebRTCSignalingService();

  webrtc.RTCPeerConnection? _peerConnection;
  webrtc.MediaStream? _localStream;
  webrtc.MediaStream? _remoteStream;

  final _remoteStreamController =
      StreamController<webrtc.MediaStream>.broadcast();
  Stream<webrtc.MediaStream> get remoteStreamStream =>
      _remoteStreamController.stream;

  final _connectionStateController =
      StreamController<webrtc.RTCPeerConnectionState>.broadcast();
  Stream<webrtc.RTCPeerConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  // WebRTC configuration
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  Future<void> initLocalStream({bool audio = true, bool video = true}) async {
    try {
      // Request permissions first
      await _requestPermissions(audio: audio, video: video);

      _localStream = await webrtc.navigator.mediaDevices.getUserMedia({
        'audio': audio,
        'video': video ? {'facingMode': 'user'} : false,
      });
    } catch (e) {
      print('Error initializing local stream: $e');
      rethrow;
    }
  }

  Future<void> _requestPermissions(
      {bool audio = true, bool video = true}) async {
    // On web, permissions are handled by the browser when getUserMedia is called
    // Skip permission requests on web platforms
    if (webrtc.WebRTC.platformIsWeb) {
      return;
    }

    List<Permission> permissions = [];

    if (video) {
      permissions.add(Permission.camera);
    }

    if (audio) {
      permissions.add(Permission.microphone);
    }

    // Request permissions
    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // Check if all permissions are granted
    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      // Handle denied permissions
      for (var entry in statuses.entries) {
        if (!entry.value.isGranted) {
          print('Permission ${entry.key} denied: ${entry.value}');
        }
      }
      throw Exception('Required permissions not granted');
    }
  }

  webrtc.MediaStream? get localStream => _localStream;

  Future<void> createPeerConnection(String callId, bool isCaller) async {
    try {
      _peerConnection = await webrtc.createPeerConnection(_configuration, {});

      // Add local stream tracks to peer connection
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });
      }

      // Listen for remote stream
      _peerConnection!.onTrack = (webrtc.RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          _remoteStreamController.add(_remoteStream!);
        }
      };

      // Listen for ICE candidates
      _peerConnection!.onIceCandidate = (webrtc.RTCIceCandidate candidate) {
        _signalingService.addIceCandidate(callId, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      // Listen for signaling state changes
      _peerConnection!.onSignalingState = (webrtc.RTCSignalingState state) {
        print('Signaling state changed: $state');
      };

      // Listen for connection state changes
      _peerConnection!.onConnectionState =
          (webrtc.RTCPeerConnectionState state) {
        print('Connection state changed: $state');
        _connectionStateController.add(state);
      };

      // Subscribe to signaling updates
      _signalingService.subscribeToCall(callId).listen((data) {
        if (data != null) {
          // Handle remote offer
          if (data['offer'] != null && !isCaller) {
            _handleRemoteOffer(data['offer'], callId);
          }

          // Handle remote answer
          if (data['answer'] != null && isCaller) {
            _handleRemoteAnswer(data['answer']);
          }

          // Handle ICE candidates
          if (data['ice_candidates'] != null) {
            final candidates = data['ice_candidates'] as List;
            for (final candidate in candidates) {
              _addIceCandidate(candidate);
            }
          }
        }
      });

      // Create offer if caller
      if (isCaller) {
        final offer = await _peerConnection!.createOffer();
        await _peerConnection!.setLocalDescription(offer);

        // Update existing call document with offer
        await _signalingService.setOffer(callId, {
          'type': offer.type,
          'sdp': offer.sdp,
        });
      }
    } catch (e) {
      print('Error creating peer connection: $e');
      rethrow;
    }
  }

  Future<void> _handleRemoteOffer(
      Map<String, dynamic> offer, String callId) async {
    try {
      final remoteOffer = webrtc.RTCSessionDescription(
        offer['sdp'],
        offer['type'],
      );
      await _peerConnection!.setRemoteDescription(remoteOffer);

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      await _signalingService.setAnswer(callId, {
        'type': answer.type,
        'sdp': answer.sdp,
      });
    } catch (e) {
      print('Error handling remote offer: $e');
    }
  }

  Future<void> _handleRemoteAnswer(Map<String, dynamic> answer) async {
    try {
      final remoteAnswer = webrtc.RTCSessionDescription(
        answer['sdp'],
        answer['type'],
      );
      await _peerConnection!.setRemoteDescription(remoteAnswer);
    } catch (e) {
      print('Error handling remote answer: $e');
    }
  }

  Future<void> _addIceCandidate(Map<String, dynamic> candidate) async {
    try {
      final iceCandidate = webrtc.RTCIceCandidate(
        candidate['candidate'],
        candidate['sdpMid'],
        candidate['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(iceCandidate);
    } catch (e) {
      print('Error adding ICE candidate: $e');
    }
  }

  Future<void> hangUp(String callId) async {
    try {
      await _signalingService.deleteCall(callId);

      _localStream?.getTracks().forEach((track) {
        track.stop();
      });

      await _peerConnection?.close();
      _peerConnection = null;
      _localStream = null;
      _remoteStream = null;
    } catch (e) {
      print('Error hanging up: $e');
    }
  }

  void dispose() {
    _remoteStreamController.close();
    _connectionStateController.close();
    hangUp('');
  }
}
