import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import '../services/call_manager.dart';
import 'dart:async';

class CallScreen extends StatefulWidget {
  final String callId;
  final bool isIncoming;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserProfilePicture;

  const CallScreen({
    super.key,
    required this.callId,
    this.isIncoming = false,
    this.otherUserId,
    this.otherUserName,
    this.otherUserProfilePicture,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  late AnimationController _ringingController;
  late Animation<double> _ringingAnimation;
  Timer? _callTimer;
  String _callDuration = '00:00';
  webrtc.RTCVideoRenderer? _remoteRenderer;
  webrtc.RTCVideoRenderer? _localRenderer;
  StreamSubscription<dynamic>? _remoteStreamSubscription;

  @override
  void initState() {
    super.initState();

    // Initialize video renderers
    _remoteRenderer = webrtc.RTCVideoRenderer();
    _remoteRenderer!.initialize();
    _localRenderer = webrtc.RTCVideoRenderer();
    _localRenderer!.initialize();

    // Ringing animation for incoming calls
    _ringingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _ringingAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _ringingController,
      curve: Curves.easeInOut,
    ));

    // Listen to remote stream
    final callManager = Provider.of<CallManager>(context, listen: false);
    _remoteStreamSubscription = callManager.remoteStreamStream.listen((stream) {
      _remoteRenderer!.srcObject = stream;
    });

    // Set local stream
    _localRenderer!.srcObject = callManager.localStream;

    // Start call timer if call is active
    _startCallTimer();
  }

  @override
  void dispose() {
    _ringingController.dispose();
    _callTimer?.cancel();
    _remoteStreamSubscription?.cancel();
    _remoteRenderer?.dispose();
    _localRenderer?.dispose();
    super.dispose();
  }

  void _startCallTimer() {
    final callManager = Provider.of<CallManager>(context, listen: false);
    if (callManager.currentCallState == CallState.inCall ||
        callManager.currentCallState == CallState.connecting) {
      _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final duration = callManager.callDuration;
        setState(() {
          _callDuration =
              '${(duration ~/ 60).toString().padLeft(2, '0')}:${(duration % 60).toString().padLeft(2, '0')}';
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallManager>(
      builder: (context, callManager, child) {
        final callState = callManager.currentCallState;
        final callData = callManager.currentCall;
        final isVideoCall = callData?.callType == CallType.video;

        // Show different UI based on call state
        switch (callState) {
          case CallState.calling:
          case CallState.ringing:
            return _buildCallingScreen(callManager, isVideoCall);
          case CallState.connecting:
          case CallState.inCall:
            return _buildInCallScreen(callManager, isVideoCall);
          case CallState.ended:
          case CallState.rejected:
          case CallState.missed:
            return _buildCallEndedScreen(callManager);
          default:
            return _buildCallingScreen(callManager, isVideoCall);
        }
      },
    );
  }

  Widget _buildCallingScreen(CallManager callManager, bool isVideoCall) {
    final callData = callManager.currentCall;
    final isIncoming = widget.isIncoming;

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: SafeArea(
        child: Column(
          children: [
            // Header with call info
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile picture with ringing animation
                  AnimatedBuilder(
                    animation: _ringingAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isIncoming ? _ringingAnimation.value : 1.0,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isIncoming ? Colors.green : Colors.white,
                              width: 4,
                            ),
                            image: widget.otherUserProfilePicture != null
                                ? DecorationImage(
                                    image: NetworkImage(
                                        widget.otherUserProfilePicture!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: widget.otherUserProfilePicture == null
                              ? CircleAvatar(
                                  radius: 56,
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    widget.otherUserName?.isNotEmpty == true
                                        ? widget.otherUserName![0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // User name
                  Text(
                    widget.otherUserName ?? 'Unknown User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Call status
                  Text(
                    isIncoming
                        ? 'Incoming ${isVideoCall ? 'video' : 'audio'} call...'
                        : 'Calling ${isVideoCall ? 'video' : 'audio'}...',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Call controls
            Container(
              padding: const EdgeInsets.all(30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Switch to video/audio
                  if (!isVideoCall)
                    FloatingActionButton(
                      heroTag: 'switch_to_video',
                      onPressed: () {
                        // TODO: Implement switching to video
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Switch to video coming soon!')),
                        );
                      },
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E3A8A),
                      child: const Icon(Icons.videocam),
                    ),

                  // Cancel/Decline button
                  FloatingActionButton(
                    heroTag: 'decline_call',
                    onPressed: () async {
                      if (isIncoming) {
                        await callManager.rejectCall(widget.callId);
                      } else {
                        await callManager.endCall();
                      }
                      Navigator.of(context).pop();
                    },
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    child: Icon(isIncoming ? Icons.call_end : Icons.call_end),
                  ),

                  // Accept button (only for incoming calls)
                  if (isIncoming)
                    FloatingActionButton(
                      heroTag: 'accept_call',
                      onPressed: () async {
                        await callManager.acceptCall(widget.callId);
                      },
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.call),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildInCallScreen(CallManager callManager, bool isVideoCall) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main video area
            if (isVideoCall)
              Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    // Remote video (full screen)
                    if (_remoteRenderer!.srcObject != null)
                      Positioned.fill(
                        child: webrtc.RTCVideoView(
                          _remoteRenderer!,
                          objectFit: webrtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          mirror: false,
                        ),
                      )
                    else
                      // Show local stream if no remote stream yet
                      if (_localRenderer!.srcObject != null)
                        Positioned.fill(
                          child: webrtc.RTCVideoView(
                            _localRenderer!,
                            objectFit: webrtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                            mirror: true,
                          ),
                        ),

                    // Local video (picture-in-picture)
                    if (_localRenderer!.srcObject != null && _remoteRenderer!.srcObject != null)
                      Positioned(
                        top: 20,
                        right: 20,
                        width: 120,
                        height: 160,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: webrtc.RTCVideoView(
                              _localRenderer!,
                              objectFit: webrtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                              mirror: true,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              // Audio call background
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Profile picture
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: widget.otherUserProfilePicture != null
                              ? DecorationImage(
                                  image: NetworkImage(
                                      widget.otherUserProfilePicture!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: widget.otherUserProfilePicture == null
                            ? CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.white,
                                child: Text(
                                  widget.otherUserName?.isNotEmpty == true
                                      ? widget.otherUserName![0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.otherUserName ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _callDuration,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Call duration (top)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _callDuration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Call controls (bottom)
            Positioned(
              bottom: 50,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  FloatingActionButton(
                    heroTag: 'mute',
                    onPressed: () => callManager.toggleMute(),
                    backgroundColor:
                        callManager.isMuted ? Colors.red : Colors.white,
                    foregroundColor: callManager.isMuted
                        ? Colors.white
                        : const Color(0xFF1E3A8A),
                    child:
                        Icon(callManager.isMuted ? Icons.mic_off : Icons.mic),
                  ),

                  // Video toggle (only for video calls)
                  if (isVideoCall)
                    FloatingActionButton(
                      heroTag: 'video_toggle',
                      onPressed: () => callManager.toggleVideo(),
                      backgroundColor: callManager.isVideoEnabled
                          ? Colors.white
                          : Colors.grey,
                      foregroundColor: callManager.isVideoEnabled
                          ? const Color(0xFF1E3A8A)
                          : Colors.white,
                      child: Icon(callManager.isVideoEnabled
                          ? Icons.videocam
                          : Icons.videocam_off),
                    ),

                  // Speaker toggle
                  FloatingActionButton(
                    heroTag: 'speaker',
                    onPressed: () => callManager.toggleSpeaker(),
                    backgroundColor:
                        callManager.isSpeakerOn ? Colors.white : Colors.grey,
                    foregroundColor: callManager.isSpeakerOn
                        ? const Color(0xFF1E3A8A)
                        : Colors.white,
                    child: Icon(callManager.isSpeakerOn
                        ? Icons.volume_up
                        : Icons.volume_off),
                  ),

                  // End call button
                  FloatingActionButton(
                    heroTag: 'end_call',
                    onPressed: () async {
                      await callManager.endCall();
                      Navigator.of(context).pop();
                    },
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.call_end),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallEndedScreen(CallManager callManager) {
    final callData = callManager.currentCall;

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Profile picture
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: widget.otherUserProfilePicture != null
                      ? DecorationImage(
                          image: NetworkImage(widget.otherUserProfilePicture!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: widget.otherUserProfilePicture == null
                    ? CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Text(
                          widget.otherUserName?.isNotEmpty == true
                              ? widget.otherUserName![0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 20),

              Text(
                widget.otherUserName ?? 'Unknown User',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Call ${callData?.state == CallState.rejected ? 'declined' : 'ended'}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3A8A),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
