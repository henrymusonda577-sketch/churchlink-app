import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:audioplayers/audioplayers.dart';
import 'webrtc_call_service.dart';
import 'webrtc_signaling_service.dart';
import 'notification_service.dart';
import '../widgets/call_screen.dart';

enum CallState {
  idle,
  calling,
  ringing,
  connecting,
  inCall,
  ended,
  rejected,
  missed
}

enum CallType { audio, video }

class CallParticipant {
  final String userId;
  final String name;
  final String? profilePictureUrl;
  dynamic videoStream;
  bool isMuted;
  bool isVideoEnabled;
  bool isConnected;

  CallParticipant({
    required this.userId,
    required this.name,
    this.profilePictureUrl,
    this.videoStream,
    this.isMuted = false,
    this.isVideoEnabled = true,
    this.isConnected = false,
  });
}

class CallData {
  final String callId;
  final String callerId;
  final String callerName;
  final CallType callType;
  final List<String> participants;
  final CallState state;
  final DateTime startTime;
  final DateTime? endTime;

  CallData({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callType,
    required this.participants,
    required this.state,
    required this.startTime,
    this.endTime,
  });
}

class CallManager extends ChangeNotifier {
      final SupabaseClient _supabase = Supabase.instance.client;
      final WebRTCCallService _callService = WebRTCCallService();
      final WebRTCSignalingService _signalingService = WebRTCSignalingService();
      final NotificationService _notificationService = NotificationService();
      final AudioPlayer _ringtonePlayer = AudioPlayer();

      // Callback for when call state changes
      Function(CallState)? onCallStateChanged;
      final GlobalKey<NavigatorState>? navigatorKey;
      bool _isCallDialogShowing = false;
      bool _isInitialized = false;

     CallManager({this.navigatorKey}) {
        print('DEBUG: CallManager constructor called');
      }

   // Call state
   CallState _currentCallState = CallState.idle;
  CallData? _currentCall;
  List<CallParticipant> _participants = [];
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;

  // Streams
  StreamSubscription<dynamic>? _callSubscription;
  Timer? _callTimer;
  int _callDuration = 0;
  StreamSubscription<webrtc.RTCPeerConnectionState>? _connectionStateSubscription;

  // Getters
  CallState get currentCallState => _currentCallState;
  CallData? get currentCall => _currentCall;
  List<CallParticipant> get participants => _participants;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isFrontCamera => _isFrontCamera;
  int get callDuration => _callDuration;
  dynamic get localStream => _callService.localStream;
  Stream<dynamic> get remoteStreamStream => _callService.remoteStreamStream;
  Stream<webrtc.RTCPeerConnectionState> get connectionStateStream => _callService.connectionStateStream;

  // Initialize call manager
  Future<void> initialize() async {
    if (_isInitialized) {
      print('DEBUG: CallManager already initialized, skipping');
      return;
    }
    print('DEBUG: CallManager.initialize() called');
    _listenToIncomingCalls();
    _isInitialized = true;
    notifyListeners();
  }

  // Start a new call
  Future<String?> startCall({
    required String recipientId,
    required CallType callType,
    String? groupId,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return null;

      // Initialize local stream
      await _callService.initLocalStream(
        audio: true,
        video: callType == CallType.video,
      );

      final callId = _generateCallId();
      final participants = groupId != null
          ? await _getGroupParticipants(groupId)
          : [currentUser.id, recipientId];

      // Create call document
      await _signalingService.createCallDocument(callId, {
        'callerId': currentUser.id,
        'callerName': await _getCurrentUserName(),
        'callType': callType == CallType.video ? 'video' : 'audio',
        'participants': participants,
        'groupId': groupId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _currentCall = CallData(
        callId: callId,
        callerId: currentUser.id,
        callerName: await _getCurrentUserName(),
        callType: callType,
        participants: participants,
        state: CallState.calling,
        startTime: DateTime.now(),
      );

      _currentCallState = CallState.calling;
      _playRingtone(); // Play ringtone for outgoing group call
      notifyListeners();
      onCallStateChanged?.call(_currentCallState);

      // Create peer connection as caller
      await _callService.createPeerConnection(callId, true);

      // Listen to connection state changes
      _connectionStateSubscription = _callService.connectionStateStream.listen(_handleConnectionStateChange);

      // Send notifications to participants
      await _sendCallNotifications(callId, participants, callType, await _getCurrentUserName());
      print('DEBUG: Call started: $callId for ${participants.length} participants, notifications sent');

      // Start call timer
      _startCallTimer();

      return callId;
    } catch (e) {
      print('Error starting call: $e');
      return null;
    }
  }

  // Start a group call with multiple participants
  Future<String?> startGroupCall({
    required List<String> participantIds,
    required CallType callType,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return null;

      // Initialize local stream
      await _callService.initLocalStream(
        audio: true,
        video: callType == CallType.video,
      );

      final callId = _generateCallId();
      final participants = [currentUser.id, ...participantIds];

      // Create call document
      await _signalingService.createCallDocument(callId, {
        'callerId': currentUser.id,
        'callerName': await _getCurrentUserName(),
        'callType': callType == CallType.video ? 'video' : 'audio',
        'participants': participants,
        'groupId': null, // Not a predefined group
        'timestamp': DateTime.now().toIso8601String(),
      });

      _currentCall = CallData(
        callId: callId,
        callerId: currentUser.id,
        callerName: await _getCurrentUserName(),
        callType: callType,
        participants: participants,
        state: CallState.calling,
        startTime: DateTime.now(),
      );

      _currentCallState = CallState.calling;
      _playRingtone(); // Play ringtone for outgoing call
      notifyListeners();
      onCallStateChanged?.call(_currentCallState);

      // Create peer connection as caller
      await _callService.createPeerConnection(callId, true);

      // Listen to connection state changes
      _connectionStateSubscription = _callService.connectionStateStream.listen(_handleConnectionStateChange);

      // Send notifications to participants
      await _sendCallNotifications(callId, participants, callType, await _getCurrentUserName());
      print(
          'Group call started: $callId for ${participants.length} participants');

      // Start call timer
      _startCallTimer();

      // Set call timeout (30 seconds)
      Future.delayed(const Duration(seconds: 30), () {
        if (_currentCallState == CallState.calling && _currentCall?.callId == callId) {
          print('DEBUG: Call timeout reached, ending call');
          endCall();
        }
      });

      return callId;
    } catch (e) {
      print('Error starting group call: $e');
      return null;
    }
  }

  // Accept incoming call
  Future<void> acceptCall(String callId) async {
    try {
      // Stop ringtone when accepting call
      await _stopRingtone();

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      // Initialize local stream based on call type
      final callData = await _supabase.from('calls').select('callType').eq('id', callId).single();
      final isVideoCall = callData['callType'] == 'video';

      await _callService.initLocalStream(
        audio: true,
        video: isVideoCall,
      );

      await _callService.createPeerConnection(callId, false);

      // Listen to connection state changes
      _connectionStateSubscription = _callService.connectionStateStream.listen(_handleConnectionStateChange);

      _currentCallState = CallState.connecting;
      notifyListeners();
      onCallStateChanged?.call(_currentCallState);

      // Update call document
      await _supabase.from('calls').update({
        'accepted_by': currentUser.id,
        'accepted_at': DateTime.now().toIso8601String(),
      }).eq('id', callId);
    } catch (e) {
      print('Error accepting call: $e');
      await rejectCall(callId);
    }
  }

  // Reject incoming call
  Future<void> rejectCall(String callId) async {
    try {
      // Stop ringtone when rejecting call
      await _stopRingtone();

      _currentCallState = CallState.rejected;
      onCallStateChanged?.call(_currentCallState);
      await _signalingService.deleteCall(callId);
      _cleanupCall();
    } catch (e) {
      print('Error rejecting call: $e');
    }
  }

  // End current call
  Future<void> endCall() async {
    try {
      // Stop ringtone when ending call
      await _stopRingtone();

      if (_currentCall != null) {
        await _signalingService.deleteCall(_currentCall!.callId);
        _currentCallState = CallState.ended;
        onCallStateChanged?.call(_currentCallState);
        _currentCall = _currentCall!.copyWith(
          state: CallState.ended,
          endTime: DateTime.now(),
        );
        _cleanupCall();
      }
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  // Toggle mute
  void toggleMute() {
    _isMuted = !_isMuted;
    if (_callService.localStream != null) {
      _callService.localStream!.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });
    }
    notifyListeners();
  }

  // Toggle speaker
  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    // TODO: Implement speaker switching logic
    notifyListeners();
  }

  // Toggle video
  void toggleVideo() {
    _isVideoEnabled = !_isVideoEnabled;
    if (_callService.localStream != null) {
      _callService.localStream!.getVideoTracks().forEach((track) {
        track.enabled = _isVideoEnabled;
      });
    }
    notifyListeners();
  }

  // Switch camera
  void switchCamera() {
    _isFrontCamera = !_isFrontCamera;
    // TODO: Implement camera switching logic
    notifyListeners();
  }

  // Play ringtone for incoming calls
  Future<void> _playRingtone() async {
    try {
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.play(AssetSource('notification_sound.mp3'));
    } catch (e) {
      print('Error playing ringtone: $e');
    }
  }

  // Stop ringtone
  Future<void> _stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
    } catch (e) {
      print('Error stopping ringtone: $e');
    }
  }

  // Listen to incoming calls
  void _listenToIncomingCalls() {
    final currentUser = _supabase.auth.currentUser;
    print('DEBUG: _listenToIncomingCalls called, currentUser: ${currentUser?.id ?? "null"}');
    if (currentUser == null) {
      print('DEBUG: No current user, cannot listen for incoming calls');
      return;
    }

    print('DEBUG: Listening for incoming calls for user: ${currentUser.id}');

    _callSubscription = _supabase
        .from('calls')
        .stream(primaryKey: ['id'])
        .listen((data) {
      print('DEBUG: Received incoming call data: $data');
      for (final callData in data) {
        // Check if this user is a participant and not the caller
        final participants = List<String>.from(callData['participants'] ?? []);
        final isParticipant = participants.contains(currentUser.id);
        final isCaller = callData['caller_id'] == currentUser.id;
        final isAccepted = callData['accepted_by'] != null;

        print('DEBUG: Call check - user: ${currentUser.id}, isParticipant: $isParticipant, isCaller: $isCaller, isAccepted: $isAccepted, participants: $participants');

        if (isParticipant && !isCaller && !isAccepted) {
          print('DEBUG: Processing incoming call for user: ${currentUser.id}');
          _handleIncomingCall(callData['id'], callData);
        }
      }
    });
  }

  // Handle incoming call
  void _handleIncomingCall(String callId, Map<String, dynamic> callData) {
    try {
      print('DEBUG: Handling incoming call: $callId, data: $callData');

      // Validate required fields
      final callerId = callData['caller_id'];
      final callerName = callData['caller_name'];
      final callType = callData['call_type'];
      final participants = callData['participants'];
      final createdAt = callData['created_at'];

      if (callerId == null || callerName == null || callType == null) {
        print('DEBUG: Missing required call data fields, skipping call handling');
        return;
      }

      // Safely convert participants list
      final participantsList = participants is List
          ? participants.where((p) => p != null).map((p) => p.toString()).toList()
          : <String>[];

      _currentCall = CallData(
        callId: callId,
        callerId: callerId.toString(),
        callerName: callerName.toString(),
        callType: callType == 'video' ? CallType.video : CallType.audio,
        participants: participantsList,
        state: CallState.ringing,
        startTime: createdAt != null
            ? DateTime.tryParse(createdAt.toString()) ?? DateTime.now()
            : DateTime.now(),
      );

      _currentCallState = CallState.ringing;
      _playRingtone(); // Play ringtone for incoming call
      notifyListeners();
      onCallStateChanged?.call(_currentCallState);

      // Show incoming call dialog directly
      if (navigatorKey != null && !_isCallDialogShowing) {
        _isCallDialogShowing = true;
        print('DEBUG: Showing incoming call dialog directly for call: $callId');
        _showIncomingCallDialog();
      }

      print('DEBUG: Incoming call handled successfully, state set to ringing');
    } catch (e, stackTrace) {
      print('DEBUG: Error handling incoming call: $e');
      print('DEBUG: Stack trace: $stackTrace');
    }
  }

  // Get group participants
  Future<List<String>> _getGroupParticipants(String groupId) async {
    final response = await _supabase.from('church_members').select('user_id').eq('church_id', groupId);
    return response.map((member) => member['user_id'] as String).toList();
  }

  // Get current user name
  Future<String> _getCurrentUserName() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser?.userMetadata?['name'] != null) {
      return currentUser!.userMetadata!['name'];
    }

    // Fallback to email or something
    return currentUser?.email ?? 'User';
  }

  // Send call notifications to participants
  Future<void> _sendCallNotifications(String callId, List<String> participants, CallType callType, String callerName) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      // Filter out the caller from participants
      final recipientIds = participants.where((id) => id != currentUser.id).toList();

      if (recipientIds.isEmpty) return;

      final callTypeText = callType == CallType.video ? 'video' : 'audio';
      final title = 'Incoming $callTypeText call';
      final body = '$callerName is calling you';

      print('DEBUG: Sending call notifications to ${recipientIds.length} participants');

      // Send notifications to all recipients
      await _notificationService.sendNotificationToUsers(
        userIds: recipientIds,
        title: title,
        body: body,
        data: {
          'type': 'call',
          'callId': callId,
          'callType': callTypeText,
          'callerId': currentUser.id,
          'callerName': callerName,
        },
      );

      print('DEBUG: Call notifications sent successfully');
    } catch (e) {
      print('Error sending call notifications: $e');
    }
  }

  // Generate unique call ID
  String _generateCallId() {
    return 'call_${DateTime.now().millisecondsSinceEpoch}_${_supabase.auth.currentUser?.id}';
  }

  // Start call timer
  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDuration++;
      notifyListeners();
    });
  }

  // Cleanup call resources
  void _cleanupCall() {
    _callTimer?.cancel();
    _callTimer = null;
    _callDuration = 0;
    _participants.clear();
    _currentCall = null;
    _currentCallState = CallState.idle;
    onCallStateChanged?.call(_currentCallState);
    // Stop ringtone during cleanup
    _stopRingtone();
    notifyListeners();
  }

  // Show incoming call dialog
  void _showIncomingCallDialog() {
    final call = _currentCall;
    if (call == null || navigatorKey == null) return;

    navigatorKey!.currentState?.push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black54,
          body: Center(
            child: AlertDialog(
              title: Text('${call.callerName} is calling'),
              content: Text('Incoming ${call.callType == CallType.video ? 'video' : 'audio'} call'),
              actions: [
                TextButton(
                  onPressed: () {
                    _isCallDialogShowing = false;
                    navigatorKey!.currentState?.pop();
                    rejectCall(call.callId);
                  },
                  child: const Text('Reject'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _isCallDialogShowing = false;
                    navigatorKey!.currentState?.pop();
                    acceptCall(call.callId).then((_) {
                      navigatorKey!.currentState?.push(
                        MaterialPageRoute(
                          builder: (context) => CallScreen(
                            callId: call.callId,
                            isIncoming: true,
                            otherUserId: call.callerId,
                            otherUserName: call.callerName,
                            otherUserProfilePicture: null,
                          ),
                        ),
                      );
                    });
                  },
                  child: const Text('Accept'),
                ),
              ],
            ),
          ),
        ),
        fullscreenDialog: true,
      ),
    ).then((_) {
      _isCallDialogShowing = false;
    });
  }

  // Handle connection state changes
  void _handleConnectionStateChange(webrtc.RTCPeerConnectionState state) {
    switch (state) {
      case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _currentCallState = CallState.inCall;
        notifyListeners();
        onCallStateChanged?.call(_currentCallState);
        break;
      case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed:
      case webrtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        // Stop ringtone for missed/failed calls
        _stopRingtone();
        _currentCallState = CallState.ended;
        onCallStateChanged?.call(_currentCallState);
        _cleanupCall();
        break;
      default:
        // Handle other states if needed
        break;
    }
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _callTimer?.cancel();
    _connectionStateSubscription?.cancel();
    _ringtonePlayer.dispose();
    _callService.hangUp(_currentCall?.callId ?? '');
    super.dispose();
  }
}

// Extension to copy CallData
extension CallDataCopy on CallData {
  CallData copyWith({
    String? callId,
    String? callerId,
    String? callerName,
    CallType? callType,
    List<String>? participants,
    CallState? state,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return CallData(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callType: callType ?? this.callType,
      participants: participants ?? this.participants,
      state: state ?? this.state,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
