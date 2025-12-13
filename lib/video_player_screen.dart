import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String videoTitle;

  const VideoPlayerScreen({
    super.key,
    required this.videoPath,
    required this.videoTitle,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      print('Initializing video player with path: ${widget.videoPath}');

      // Validate video URL/path
      if (widget.videoPath.isEmpty) {
        setState(() {
          _errorMessage = 'Video URL is empty';
        });
        return;
      }

      if (widget.videoPath.startsWith('http')) {
        // Network URL (signed URL from Firebase Storage)
        print('Using network source for signed URL');

        // Validate URL format
        final uri = Uri.tryParse(widget.videoPath);
        if (uri == null || !uri.hasScheme) {
          setState(() {
            _errorMessage = 'Invalid video URL format';
          });
          return;
        }

        _controller = VideoPlayerController.network(widget.videoPath);
      } else if (kIsWeb) {
        // On web, create controller from network source
        print('Running on web platform, using network source');
        _controller = VideoPlayerController.network(widget.videoPath);
      } else {
        // On mobile, check if the file exists
        final file = File(widget.videoPath);
        final exists = await file.exists();
        print('File exists: $exists');

        if (!exists) {
          setState(() {
            _errorMessage = 'Video file not found: ${widget.videoPath}';
          });
          return;
        }

        // Get file info
        final fileInfo = await file.stat();
        print('File size: ${fileInfo.size} bytes');
        print('File path: ${file.absolute.path}');

        // Create video player controller
        _controller = VideoPlayerController.file(file);
      }

      // Initialize the controller with timeout
      print('Initializing video controller...');

      // Set up error listener before initialization
      _controller!.addListener(() {
        if (!mounted) return;

        final value = _controller!.value;
        if (value.hasError) {
          print('Video player error: ${value.errorDescription}');
          setState(() {
            _errorMessage = 'Video cannot be played: ${value.errorDescription ?? "Unknown error"}';
            _isInitialized = false;
          });
        } else if (value.isInitialized) {
          setState(() {
            _position = value.position;
            _duration = value.duration;
            _isInitialized = true;
          });
        }
      });

      // Initialize with timeout to prevent hanging
      await _controller!.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('Video initialization timed out');
          throw Exception('Video initialization timed out');
        },
      );

      print('Video controller initialized successfully');

      if (mounted && _errorMessage == null) {
        setState(() {
          _isInitialized = true;
        });
        print('Video player state updated');
      }
    } catch (e, stackTrace) {
      print('Error initializing video player: $e');
      print('Stack trace: $stackTrace');

      String errorMsg = 'Video cannot be played';
      if (e.toString().contains('timeout')) {
        errorMsg = 'Video loading timed out. Please check your connection.';
      } else if (e.toString().contains('network')) {
        errorMsg = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('format')) {
        errorMsg = 'Video format not supported.';
      }

      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _playPause() {
    if (_controller == null) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _seekTo(Duration position) {
    if (_controller == null) return;
    _controller!.seekTo(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.videoTitle),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error Loading Video',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                        _initializeVideoPlayer();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_isInitialized && _controller != null)
            Center(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height *
                      0.6, // Limit to 60% of screen height
                  maxWidth: MediaQuery.of(context).size.width *
                      0.9, // Limit to 90% of screen width
                ),
                margin: const EdgeInsets.symmetric(vertical: 20),
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading video...'),
                  ],
                ),
              ),
            ),
          if (_isInitialized &&
              _controller != null &&
              _errorMessage == null) ...[
            // Video progress bar
            if (_duration.inMilliseconds > 0)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Progress slider
                    Slider(
                      value: _position.inMilliseconds
                          .clamp(0, _duration.inMilliseconds)
                          .toDouble(),
                      min: 0,
                      max: _duration.inMilliseconds.toDouble(),
                      onChanged: (value) {
                        _seekTo(Duration(milliseconds: value.toInt()));
                      },
                      activeColor: const Color(0xFF1E3A8A),
                    ),
                    // Time display
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(_position)),
                          Text(_formatDuration(_duration)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Video controls
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      final newPosition =
                          _position - const Duration(seconds: 10);
                      _seekTo(newPosition);
                    },
                    icon: const Icon(Icons.replay_10),
                    iconSize: 32,
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    onPressed: _playPause,
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    iconSize: 48,
                    color: const Color(0xFF1E3A8A),
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    onPressed: () {
                      final newPosition =
                          _position + const Duration(seconds: 10);
                      _seekTo(newPosition);
                    },
                    icon: const Icon(Icons.forward_10),
                    iconSize: 32,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
