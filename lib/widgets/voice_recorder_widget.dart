import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart' as audio_pkg;
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart';

enum RecorderState { idle, recording, preview }

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String, int) onSend; // filePath, durationSeconds

  const VoiceRecorderWidget({super.key, required this.onSend});

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  late Record _recorder;
  final audio_pkg.AudioPlayer _player = audio_pkg.AudioPlayer();
  RecorderState _state = RecorderState.idle;
  String? _recordedFilePath;
  Duration _recordingDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _timer;
  RecorderController? _recorderController;

  @override
  void initState() {
    super.initState();
    _recorder = Record.instance;
    _initializeRecorder();
    _player.onPositionChanged.listen((position) {
      setState(() {
        _playbackPosition = position;
      });
    });
    _player.onDurationChanged.listen((duration) {
      setState(() {
        _totalDuration = duration ?? Duration.zero;
      });
    });
    _player.onPlayerComplete.listen((event) {
      setState(() {
        _playbackPosition = Duration.zero;
      });
    });
  }

  Future<void> _initializeRecorder() async {
    _recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _timer?.cancel();
    _recorderController?.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder.start(
        path: filePath,
      );

      setState(() {
        _state = RecorderState.recording;
        _recordingDuration = Duration.zero;
        _recordedFilePath = filePath;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      });

      await _recorderController?.record();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      _timer?.cancel();
      await _recorderController?.stop();

      if (path != null) {
        setState(() {
          _state = RecorderState.preview;
          _recordedFilePath = path;
        });
        await _player.setSource(audio_pkg.DeviceFileSource(path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $e')),
      );
    }
  }

  Future<void> _playPause() async {
    if (_player.state == audio_pkg.PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  void _seekTo(Duration position) {
    _player.seek(position);
  }

  void _deleteRecording() {
    setState(() {
      _state = RecorderState.idle;
      _recordedFilePath = null;
      _recordingDuration = Duration.zero;
      _playbackPosition = Duration.zero;
      _totalDuration = Duration.zero;
    });
  }

  void _reRecord() {
    _deleteRecording();
    _startRecording();
  }

  void _sendRecording() {
    if (_recordedFilePath != null) {
      widget.onSend(_recordedFilePath!, _totalDuration.inSeconds);
      _deleteRecording();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_state == RecorderState.recording) ...[
            const Text(
              'Recording...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            AudioWaveforms(
              enableGesture: false,
              size: Size(MediaQuery.of(context).size.width * 0.8, 50),
              recorderController: _recorderController!,
              waveStyle: const WaveStyle(
                waveColor: Colors.blue,
                extendWaveform: true,
                showMiddleLine: false,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDuration(_recordingDuration),
              style: const TextStyle(fontSize: 20, color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ] else if (_state == RecorderState.preview) ...[
            const Text(
              'Preview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _player.state == audio_pkg.PlayerState.playing
                        ? Icons.pause
                        : Icons.play_arrow,
                    size: 32,
                  ),
                  onPressed: _playPause,
                ),
                Expanded(
                  child: Slider(
                    value: _playbackPosition.inMilliseconds.toDouble(),
                    max: _totalDuration.inMilliseconds.toDouble(),
                    onChanged: (value) {
                      _seekTo(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
                Text(_formatDuration(_totalDuration)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _deleteRecording,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _reRecord,
                  icon: const Icon(Icons.mic),
                  label: const Text('Re-record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _sendRecording,
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.mic),
              label: const Text('Record Voice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
