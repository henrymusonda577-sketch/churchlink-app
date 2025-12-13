import 'dart:async';
import 'dart:io' as io;
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'camera_screen.dart';
import 'tiktok_feed_screen.dart';
import 'services/post_service.dart';
import 'services/community_service.dart';
import 'services/video_firebase_service.dart';
import 'services/audio_firebase_service.dart';
import 'services/gospel_songs_service.dart';
import 'services/moderation_service.dart';
import 'services/user_service.dart';
import 'services/event_service.dart';

class ContentScreen extends StatefulWidget {
  final Map<String, String> userInfo;
  final int initialTab;
  const ContentScreen({Key? key, required this.userInfo, this.initialTab = 0})
      : super(key: key);

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> with SingleTickerProviderStateMixin {
  final List<XFile> _videos = [];
  final List<VideoPlayerController> _videoControllers = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  final PostService _postService = PostService();
  final CommunityService _communityService = CommunityService();
  final GospelSongsService _gospelSongsService = GospelSongsService();
  final UserService _userService = UserService();
  final AudioFirebaseService _audioFirebaseService = AudioFirebaseService();
  final VideoFirebaseService _videoFirebaseService = VideoFirebaseService();
  final EventService _eventService = EventService();
  final List<Map<String, dynamic>> _events = [];
  final Map<int, List<String>> _eventRSVPs = {};
  int? _currentlyPlayingSongIdx;
  YoutubePlayerController? _youtubeController;
  int? _selectedSongIdx;
  bool _isUploadingVideo = false;
  double _uploadProgress = 0.0;

  // Event filtering
  String _eventSearchQuery = '';
  String? _selectedEventCategory;
  String _eventSortBy = 'date';

  // Tab management
  late TabController _tabController;
  int _currentTabIndex = 0;
  final GlobalKey<TikTokFeedScreenState> _videosKey = GlobalKey();

  void _onTabChanged() {
    setState(() {
      _currentTabIndex = _tabController.index;
    });
    if (_currentTabIndex != 0) {
      _videosKey.currentState?.pauseAllVideos();
    }
  }

  final Uuid _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _currentTabIndex = widget.initialTab;
    _tabController.addListener(_onTabChanged);
    _gospelSongsService.initializeCuratedSongs();
  }

  Future<String?> _uploadVideoToStorage(XFile videoFile) async {
    try {
      // Upload to Supabase Storage instead of Firebase
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      // Determine file extension
      String extension = 'mp4'; // default
      if (videoFile.name.contains('.')) {
        extension = videoFile.name.split('.').last.toLowerCase();
      }

      final fileName = 'videos/${user.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final fileBytes = await videoFile.readAsBytes();

      await supabase.storage.from('videos').uploadBinary(fileName, fileBytes);
      final publicUrl = supabase.storage.from('videos').getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print('Error uploading video to Supabase Storage: $e');
      return null;
    }
  }

  Future<String?> _uploadAudioToStorage(io.File audioFile, String fileName) async {
    try {
      // Upload to Supabase Storage
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final fileBytes = await audioFile.readAsBytes();
      final storageFileName = 'audio/${user.id}_${DateTime.now().millisecondsSinceEpoch}_${fileName}';

      await supabase.storage.from('audio').uploadBinary(storageFileName, fileBytes);
      final publicUrl = supabase.storage.from('audio').getPublicUrl(storageFileName);

      return publicUrl;
    } catch (e) {
      print('Error uploading audio to Supabase Storage: $e');
      return null;
    }
  }


  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _videoControllers) {
      controller.dispose();
    }
    _audioPlayer.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }


  void _showAddSongDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Song'),
        content: const Text('Choose how to add the song:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () {
              Navigator.of(context).pop();
              _showUploadAudioDialog();
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Audio File'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () {
              Navigator.of(context).pop();
              _showAddYouTubeDialog();
            },
            icon: const Icon(Icons.video_library),
            label: const Text('Add YouTube URL'),
          ),
        ],
      ),
    );
  }

  void _showUploadAudioDialog() {
    final titleController = TextEditingController();
    final artistController = TextEditingController();
    PlatformFile? pickedFile;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Upload Audio Song'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Pick Audio File (MP3, WAV, AAC)'),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['mp3', 'wav', 'aac'],
                    );
                    if (result != null && result.files.isNotEmpty) {
                      setStateDialog(() {
                        pickedFile = result.files.first;
                        errorMessage = null;
                      });
                    }
                  },
                ),
                if (pickedFile != null) ...[
                  const SizedBox(height: 12),
                  Text('Selected file: ${pickedFile!.name}'),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(errorMessage!,
                      style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Song Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: artistController,
                  decoration: const InputDecoration(labelText: 'Artist Name'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: () async {
                final title = titleController.text.trim();
                final artist = artistController.text.trim();

                if (pickedFile == null) {
                  setStateDialog(() {
                    errorMessage = 'Please select an audio file.';
                  });
                  return;
                }
                if (title.isEmpty || artist.isEmpty) {
                  setStateDialog(() {
                    errorMessage = 'Please fill in all fields.';
                  });
                  return;
                }

                // Validate file format and size
                final validation = await _audioFirebaseService.validateAudio(
                    kIsWeb ? pickedFile!.bytes : pickedFile!.path);
                if (validation == null || validation['valid'] == false) {
                  setStateDialog(() {
                    errorMessage =
                        validation?['error'] ?? 'Invalid audio file.';
                  });
                  return;
                }

                // Show upload progress dialog
                double uploadProgress = 0.0;
                late Function setStateProgress = () {}; // Initialize with no-op
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => StatefulBuilder(
                    builder: (context, setState) {
                      setStateProgress = setState; // Assign the actual setState
                      return AlertDialog(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LinearProgressIndicator(
                                value: uploadProgress / 100),
                            const SizedBox(height: 16),
                            Text(
                                'Uploading song... ${uploadProgress.toStringAsFixed(0)}%'),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );

                // Upload audio file
                final userId = widget.userInfo['name'] ?? 'anonymous';
                final uniqueId = _uuid.v4();
                String? downloadUrl;
                try {
                  final audioFile = kIsWeb ? io.File('temp') : io.File(pickedFile!.path!);
                  if (kIsWeb) {
                    // For web, write bytes to temp file
                    final tempDir = await getTemporaryDirectory();
                    final tempFile = io.File('${tempDir.path}/temp_audio');
                    await tempFile.writeAsBytes(pickedFile!.bytes!);
                    downloadUrl = await _uploadAudioToStorage(tempFile, pickedFile!.name);
                  } else {
                    downloadUrl = await _uploadAudioToStorage(audioFile, pickedFile!.name);
                  }
                  // Simulate progress
                  setStateProgress(() => uploadProgress = 100);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Upload failed: $e'),
                        backgroundColor: Colors.red),
                  );
                }

                if (downloadUrl == null) {
                  Navigator.of(context).pop(); // Close upload dialog
                  return;
                }

                // Save song metadata to Supabase
                final songData = {
                  'type': 'audio',
                  'title': title,
                  'artist': artist,
                  'file_url': downloadUrl,
                  'uploader_id': userId,
                  'upload_timestamp': DateTime.now().toIso8601String(),
                  'unique_id': uniqueId,
                  'file_name': pickedFile!.name,
                  'file_size': validation['size'] ?? 0,
                };
                await Supabase.instance.client
                    .from('songs')
                    .insert(songData);


                Navigator.of(context).pop(); // Close upload dialog
                Navigator.of(context).pop(); // Close add song dialog

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Song uploaded successfully!'),
                      backgroundColor: Colors.green),
                );
              },
              child: const Text('Upload Song'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddYouTubeDialog() {
    final titleController = TextEditingController();
    final artistController = TextEditingController();
    final urlController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Add YouTube Song'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'YouTube URL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Song Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: artistController,
                  decoration: const InputDecoration(labelText: 'Artist Name'),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    'Copyright Notice: By uploading this song, you confirm that you own the copyright or have permission to use this material. Church-Link is not responsible for copyright violations.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(errorMessage!,
                      style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: () async {
                final url = urlController.text.trim();
                final title = titleController.text.trim();
                final artist = artistController.text.trim();

                if (url.isEmpty || title.isEmpty || artist.isEmpty) {
                  setStateDialog(() {
                    errorMessage = 'Please fill in all fields.';
                  });
                  return;
                }

                final videoId = _extractYouTubeVideoId(url);
                if (videoId == null) {
                  setStateDialog(() {
                    errorMessage = 'Invalid YouTube URL.';
                  });
                  return;
                }

                final thumbnailUrl = _getYouTubeThumbnailUrl(videoId);

                // Save song metadata to Supabase
                final userId = widget.userInfo['name'] ?? 'anonymous';
                final uniqueId = _uuid.v4();
                final songData = {
                  'type': 'youtube',
                  'title': title,
                  'artist': artist,
                  'youtube_url': url,
                  'thumbnail_url': thumbnailUrl,
                  'video_id': videoId,
                  'uploader_id': userId,
                  'upload_timestamp': DateTime.now().toIso8601String(),
                  'unique_id': uniqueId,
                };
                await Supabase.instance.client
                    .from('songs')
                    .insert(songData);


                Navigator.of(context).pop(); // Close add song dialog

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('YouTube song added successfully!'),
                      backgroundColor: Colors.green),
                );
              },
              child: const Text('Add Song'),
            ),
          ],
        ),
      ),
    );
  }

  String? _extractYouTubeVideoId(String url) {
    final regExp = RegExp(
        r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})');
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  String _getYouTubeThumbnailUrl(String videoId) {
    return 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
  }

  void _showAddOptionsMenu() {
    // Determine source based on current tab
    String source = _currentTabIndex == 0 ? 'tiktok' : 'home';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam, color: Color(0xFF1E3A8A)),
              title: const Text('Add Video'),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndAddVideo(source);
              },
            ),
            ListTile(
              leading: const Icon(Icons.music_note, color: Color(0xFF1E3A8A)),
              title: const Text('Add Song'),
              onTap: () {
                Navigator.pop(context);
                _showAddSongDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.event, color: Color(0xFF1E3A8A)),
              title: const Text('Add Event'),
              onTap: () {
                Navigator.pop(context);
                _showAddEventDialog();
              },
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _pickAndAddVideo(String postSource) async {
    final source = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Video Source'),
        content: const Text(
            'Would you like to record a new video or select from your files?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () => Navigator.of(context).pop('camera'),
            icon: const Icon(Icons.videocam),
            label: const Text('Record Video'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E3A8A),
              side: const BorderSide(color: Color(0xFF1E3A8A)),
            ),
            onPressed: () => Navigator.of(context).pop('gallery'),
            icon: const Icon(Icons.video_library),
            label: const Text('From Files'),
          ),
        ],
      ),
    );
    XFile? video;
    if (source == 'camera') {
      final ImagePicker picker = ImagePicker();
      video = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 25),
      );
    } else if (source == 'gallery') {
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          allowMultiple: false,
        );
        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          video = XFile.fromData(file.bytes!, name: file.name);
        }
      } else {
        final ImagePicker picker = ImagePicker();
        video = await picker.pickVideo(source: ImageSource.gallery);
      }
    }

    print('DEBUG: Picked video: ${video?.path}');
    if (video != null) {
        // Validate video size before upload
        final validation = await _videoFirebaseService.validateVideo(video);
        if (validation == null || validation['valid'] == false) {
          final error = validation?['error'] ?? 'Invalid video file';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Show upload progress in screen
        setState(() {
          _isUploadingVideo = true;
          _uploadProgress = 0.0;
        });

        try {
          // Upload video to Firebase Storage with progress and retry logic
          final videoUrl = await _videoFirebaseService.uploadVideo(
            video,
            userId: widget.userInfo['name'],
            onProgress: (progress) {
              if (mounted) {
                setState(() {
                  _uploadProgress = progress;
                });
              }
            },
            onError: (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          );
          if (videoUrl != null) {
            // Create post using CommunityService with appropriate source
            await _communityService.createCommunityPost(
              content: 'Content Video', // Default content for videos
              postType: 'video',
              videoUrl: videoUrl,
              source: postSource,
            );

            // Hide upload progress
            if (mounted) {
              setState(() {
                _isUploadingVideo = false;
              });
            }

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video posted successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            throw Exception('Failed to upload video to storage');
          }
        } catch (e) {
          // Hide upload progress
          if (mounted) {
            setState(() {
              _isUploadingVideo = false;
            });
          }

          // Show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading video: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        print('DEBUG: No video selected');
      }
  }

  Future<void> _toggleEventAttendance(Map<String, dynamic> event) async {
    try {
      await _eventService.toggleAttendance(event['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance updated successfully!')),
      );
    } catch (e) {
      print('Error toggling attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update attendance')),
      );
    }
  }

  void _showAddEventDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    final locationController = TextEditingController();
    final maxAttendeesController = TextEditingController();
    String selectedType = 'general';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Add Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Event Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dateController,
                        decoration: const InputDecoration(
                            labelText: 'Date (YYYY-MM-DD)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: timeController,
                        decoration: const InputDecoration(
                            labelText: 'Time (HH:MM)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxAttendeesController,
                  decoration: const InputDecoration(labelText: 'Max Attendees (optional)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Event Type'),
                  items: [
                    'service',
                    'study',
                    'youth',
                    'social',
                    'general'
                  ]
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      selectedType = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: () async {
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();
                final date = dateController.text.trim();
                final time = timeController.text.trim();
                final location = locationController.text.trim();
                final maxAttendees = maxAttendeesController.text.isNotEmpty
                    ? int.tryParse(maxAttendeesController.text.trim())
                    : null;

                if (title.isNotEmpty && date.isNotEmpty && location.isNotEmpty) {
                  try {
                    await _eventService.createEvent(
                      title: title,
                      description: description,
                      eventDate: DateTime.parse(date),
                      eventTime: time,
                      location: location,
                      eventType: selectedType,
                      maxAttendees: maxAttendees,
                    );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Event created successfully!')),
                    );
                  } catch (e) {
                    print('Error creating event: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to create event')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all required fields')),
                  );
                }
              },
              child: const Text('Add Event'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditEventDialog(int idx) {
    final event = _events[idx];
    final titleController = TextEditingController(text: event['title']);
    final descriptionController =
        TextEditingController(text: event['description']);
    final dateController = TextEditingController(text: event['date']);
    final timeController = TextEditingController(text: event['time']);
    final locationController = TextEditingController(text: event['location']);
    final maxAttendeesController =
        TextEditingController(text: event['maxAttendees'].toString());
    String selectedCategory = event['category'] ?? 'Other';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Edit Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Event Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dateController,
                        decoration: const InputDecoration(
                            labelText: 'Date (YYYY-MM-DD)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: timeController,
                        decoration: const InputDecoration(
                            labelText: 'Time (HH:MM AM/PM)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxAttendeesController,
                  decoration: const InputDecoration(labelText: 'Max Attendees'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    'Service',
                    'Study',
                    'Outreach',
                    'Worship',
                    'Prayer',
                    'Other'
                  ]
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      selectedCategory = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: () {
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();
                final date = dateController.text.trim();
                final time = timeController.text.trim();
                final location = locationController.text.trim();
                final maxAttendees =
                    int.tryParse(maxAttendeesController.text.trim());

                if (title.isNotEmpty &&
                    date.isNotEmpty &&
                    time.isNotEmpty &&
                    location.isNotEmpty &&
                    maxAttendees != null) {
                  setState(() {
                    _events[idx] = {
                      ...event,
                      'title': title,
                      'description': description,
                      'date': date,
                      'time': time,
                      'location': location,
                      'category': selectedCategory,
                      'maxAttendees': maxAttendees,
                    };
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Event updated successfully!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Please fill in all required fields and max attendees must be a number.')),
                  );
                }
              },
              child: const Text('Update Event'),
            ),
          ],
        ),
      ),
    );
  }


  void _showEventDetailsDialog(Map<String, dynamic> event) {
    final attendees = List<String>.from(event['attendees'] ?? []);
    final maxAttendees = event['max_attendees'] as int?;
    final eventDate = DateTime.parse(event['event_date']);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final isAttending = attendees.contains(currentUserId);
    final isOrganizer = event['user_id'] == currentUserId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event['title'] ?? 'Event Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event['description'] ?? '',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              _buildEventInfoRow(
                  '📅 Date & Time', '${eventDate.toString().split(' ')[0]} ${event['event_time'] ?? ''}'),
              _buildEventInfoRow('📍 Location', event['location'] ?? ''),
              _buildEventInfoRow('🏷️ Type', event['event_type']?.toString().toUpperCase() ?? 'OTHER'),
              if (maxAttendees != null)
                _buildEventInfoRow('👥 Max Attendees', '$maxAttendees'),
              _buildEventInfoRow('✅ Attendees', '${attendees.length}'),
              const SizedBox(height: 16),
              if (attendees.isNotEmpty) ...[
                const Text(
                  'Attendees:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...attendees.take(5).map((userId) => FutureBuilder<Map<String, dynamic>?>(
                      future: Supabase.instance.client
                          .from('users')
                          .select('name')
                          .eq('id', userId)
                          .single(),
                      builder: (context, snapshot) {
                        final name = snapshot.data?['name'] ?? 'Unknown User';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: Color(0xFF1E3A8A)),
                              const SizedBox(width: 8),
                              Text(name),
                            ],
                          ),
                        );
                      },
                    )),
                if (attendees.length > 5)
                  Text('+${attendees.length - 5} more', style: const TextStyle(color: Colors.grey)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (isOrganizer)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Event'),
                    content: const Text('Are you sure you want to delete this event? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  try {
                    await _eventService.deleteEvent(event['id']);
                    Navigator.of(context).pop(); // Close event details dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Event deleted successfully!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to delete event')),
                    );
                  }
                }
              },
              child: const Text('Delete Event'),
            ),
          if (!isAttending && !isOrganizer)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _toggleEventAttendance(event);
              },
              child: const Text('Join Event'),
            ),
          if (isAttending && !isOrganizer)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _toggleEventAttendance(event);
              },
              child: const Text('Leave Event'),
            ),
        ],
      ),
    );
  }

  Widget _buildEventInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _formatEventDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = date.difference(now);

      if (difference.isNegative) {
        return 'Past';
      } else if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Tomorrow';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks weeks';
      } else {
        final months = (difference.inDays / 30).floor();
        return '$months months';
      }
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildVideosTab() {
    // Always show TikTok-style feed screen, even when no videos are available
    // The TikTokFeedScreen will handle showing available videos or a placeholder
    return TikTokFeedScreen(key: _videosKey);
  }



  Widget _buildEventsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _eventService.getEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error loading events',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final events = snapshot.data ?? [];

        if (events.isEmpty) {
          return Center(
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event, size: 80, color: Color(0xFF1E3A8A)),
                    const SizedBox(height: 16),
                    const Text('No events yet',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A))),
                    const SizedBox(height: 8),
                    const Text('Stay tuned for upcoming events.',
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
            ),
          );
        }

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: events.length,
              itemBuilder: (context, idx) {
                final event = events[idx];
                final attendees = List<String>.from(event['attendees'] ?? []);
                final maxAttendees = event['max_attendees'] as int?;
                final eventDate = DateTime.parse(event['event_date']);
                final timeUntil = _formatEventDate(event['event_date']);
                final isAttending = attendees.contains(Supabase.instance.client.auth.currentUser?.id ?? '');

                return Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  margin: const EdgeInsets.only(
                      bottom: 32, left: 16, right: 16),
                  child: InkWell(
                    onTap: () => _showEventDetailsDialog(event),
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event title and category
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event['title'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(event['event_type']),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  event['event_type']?.toString().toUpperCase() ?? 'OTHER',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Event description
                          Text(
                            event['description'] ?? '',
                            style: const TextStyle(fontSize: 16, height: 1.4),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 16),

                          // Event details
                          Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text(
                                '${eventDate.toString().split(' ')[0]} ${event['event_time'] ?? ''}',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[600]),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text(
                                event['location'] ?? '',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[600]),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Time until event and attendee count
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getTimeColor(timeUntil),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  timeUntil,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${attendees.length}${maxAttendees != null ? '/$maxAttendees' : ''} attending',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[600]),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Join/Attending button
                          if (isAttending)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green[700], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'You\'re attending!',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _toggleEventAttendance(event),
                                child: const Text('Join Event'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton.extended(
                  heroTag: 'events_fab',
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Event'),
                  onPressed: _showAddEventDialog,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'service':
        return Colors.blue;
      case 'study':
        return Colors.green;
      case 'outreach':
        return Colors.orange;
      case 'worship':
        return Colors.purple;
      case 'prayer':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getTimeColor(String timeUntil) {
    if (timeUntil == 'Past') return Colors.grey;
    if (timeUntil == 'Today') return Colors.red;
    if (timeUntil == 'Tomorrow') return Colors.orange;
    if (timeUntil.contains('days') &&
        int.tryParse(timeUntil.split(' ')[0])! < 3) return Colors.orange;
    return Colors.green;
  }

  List<Map<String, dynamic>> _getFilteredAndSortedEvents() {
    List<Map<String, dynamic>> filteredEvents = List.from(_events);

    // Filter by search query
    if (_eventSearchQuery.isNotEmpty) {
      filteredEvents = filteredEvents.where((event) {
        final title = event['title']?.toString().toLowerCase() ?? '';
        final description =
            event['description']?.toString().toLowerCase() ?? '';
        final location = event['location']?.toString().toLowerCase() ?? '';
        final organizer = event['organizer']?.toString().toLowerCase() ?? '';
        final query = _eventSearchQuery.toLowerCase();

        return title.contains(query) ||
            description.contains(query) ||
            location.contains(query) ||
            organizer.contains(query);
      }).toList();
    }

    // Filter by category
    if (_selectedEventCategory != null && _selectedEventCategory != 'All') {
      filteredEvents = filteredEvents.where((event) {
        return event['category'] == _selectedEventCategory;
      }).toList();
    }

    // Sort events
    filteredEvents.sort((a, b) {
      switch (_eventSortBy) {
        case 'date':
          try {
            final dateA = DateTime.parse(a['date'] ?? '');
            final dateB = DateTime.parse(b['date'] ?? '');
            return dateA.compareTo(dateB);
          } catch (e) {
            return 0;
          }
        case 'title':
          return (a['title'] ?? '')
              .toString()
              .compareTo((b['title'] ?? '').toString());
        case 'category':
          return (a['category'] ?? '')
              .toString()
              .compareTo((b['category'] ?? '').toString());
        case 'attendees':
          final attendeesA = _eventRSVPs[_events.indexOf(a)]?.length ?? 0;
          final attendeesB = _eventRSVPs[_events.indexOf(b)]?.length ?? 0;
          return attendeesB.compareTo(attendeesA); // Most attendees first
        default:
          return 0;
      }
    });

    return filteredEvents;
  }

  Widget _buildEventFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search bar
          TextField(
            onChanged: (value) {
              setState(() {
                _eventSearchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search events...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          const SizedBox(height: 12),

          // Category and sort filters
          Row(
            children: [
              // Category filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedEventCategory ?? 'All',
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'All',
                    'Service',
                    'Study',
                    'Outreach',
                    'Worship',
                    'Prayer',
                    'Other'
                  ]
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedEventCategory = value == 'All' ? null : value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Sort by filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _eventSortBy,
                  decoration: const InputDecoration(
                    labelText: 'Sort by',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'date', child: Text('Date')),
                    DropdownMenuItem(value: 'title', child: Text('Title')),
                    DropdownMenuItem(
                        value: 'category', child: Text('Category')),
                    DropdownMenuItem(
                        value: 'attendees', child: Text('Most Popular')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _eventSortBy = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSongsTab() {
    return Column(
      children: [
        // Content
        Expanded(
          child: _buildYouTubeSongsSection(),
        ),
      ],
    );
  }

  Widget _buildYouTubeSongsSection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _gospelSongsService.getCuratedSongsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          // Handle offline/error case by using local curated songs
          final localSongs = _gospelSongsService.getCuratedGospelSongs();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 32),
            itemCount: localSongs.length,
            itemBuilder: (context, idx) {
              final song = localSongs[idx];
              final isPlaying = _currentlyPlayingSongIdx == idx;

              return Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                margin: const EdgeInsets.only(bottom: 32, left: 16, right: 16),
                child: Column(
                  children: [
                    ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: song['thumbnailUrl'] ?? '',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const CircularProgressIndicator(),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        ),
                      ),
                      title: Text(song['title'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(song['artist'] ?? ''),
                      trailing: IconButton(
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                            color: const Color(0xFF1E3A8A)),
                        onPressed: () async {
                          developer.log('ContentScreen: Play button pressed for curated song: ${song['title']} by ${song['artist']}',
                              name: 'ContentScreen');
                          developer.log('ContentScreen: Video ID: ${song['videoId']}, Platform: ${kIsWeb ? 'Web' : 'Mobile'}',
                              name: 'ContentScreen');
 
                          if (isPlaying) {
                            print('DEBUG: Pausing current YouTube video');
                            _youtubeController?.pause();
                            setState(() {
                              _currentlyPlayingSongIdx = null;
                              _selectedSongIdx = null;
                            });
                          } else {
                            print('DEBUG: Initializing YouTube controller');
                            try {
                              // Initialize and play YouTube video
                              _youtubeController?.dispose();
                              _youtubeController = YoutubePlayerController(
                                initialVideoId: song['videoId'] ?? '',
                                flags: const YoutubePlayerFlags(
                                  autoPlay: true,
                                  mute: false,
                                ),
                              );
                              print(
                                  'DEBUG: YouTube controller created successfully');
                              await _audioPlayer.stop();
                              setState(() {
                                _currentlyPlayingSongIdx = idx;
                                _selectedSongIdx = idx;
                              });
                              print(
                                  'DEBUG: State updated, YouTube player should appear');
                            } catch (e) {
                              print(
                                  'DEBUG: Error initializing YouTube controller: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Error playing YouTube video: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    if (_selectedSongIdx == idx && _youtubeController != null)
                      Builder(
                        builder: (context) {
                          print(
                              'DEBUG: Building YouTube player for song index: $idx');
                          print(
                              'DEBUG: Controller is null: ${_youtubeController == null}');
                          return YoutubePlayer(
                            controller: _youtubeController!,
                            aspectRatio: 16 / 9,
                            showVideoProgressIndicator: true,
                            progressIndicatorColor: Colors.blueAccent,
                            onReady: () {
                              print('DEBUG: YouTube player onReady called');
                              _youtubeController!.play();
                            },
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Initialize curated songs if none exist
          _gospelSongsService.initializeCuratedSongs();
          return Center(
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.music_note, size: 80, color: Color(0xFF1E3A8A)),
                    SizedBox(height: 16),
                    Text('Loading Gospel Songs...',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A))),
                    SizedBox(height: 8),
                    Text('Curated public domain hymns will appear here',
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
            ),
          );
        }

        final songs = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 32),
          itemCount: songs.length,
          itemBuilder: (context, idx) {
            final data = songs[idx];
            final isPlaying = _currentlyPlayingSongIdx == idx;
            final isYouTube =
                data['type'] == 'youtube' || data['type'] == 'curated';

            return Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              margin: const EdgeInsets.only(bottom: 32, left: 16, right: 16),
              child: Column(
                children: [
                  ListTile(
                    leading: isYouTube
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: data['thumbnail_url'] ?? '',
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  const CircularProgressIndicator(),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            ),
                          )
                        : const Icon(Icons.music_note,
                            color: Color(0xFF1E3A8A)),
                    title: Text(data['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(data['artist'] ?? ''),
                    trailing: IconButton(
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                          color: const Color(0xFF1E3A8A)),
                      onPressed: () async {
                        developer.log('ContentScreen: Play button pressed for streamed song: ${data['title']} by ${data['artist']}',
                            name: 'ContentScreen');
                        developer.log('ContentScreen: Video ID: ${data['video_id']}, Type: ${data['type']}, Platform: ${kIsWeb ? 'Web' : 'Mobile'}',
                            name: 'ContentScreen');
 
                        if (isPlaying) {
                          print('DEBUG: Pausing current YouTube video');
                          _youtubeController?.pause();
                          setState(() {
                            _currentlyPlayingSongIdx = null;
                            _selectedSongIdx = null;
                          });
                        } else {
                          print(
                              'DEBUG: Initializing YouTube controller for streamed song');
                          try {
                            // Initialize and play YouTube video
                            _youtubeController?.dispose();
                            _youtubeController = YoutubePlayerController(
                              initialVideoId: data['video_id'] ?? '',
                              flags: const YoutubePlayerFlags(
                                autoPlay: true,
                                mute: false,
                              ),
                            );
                            print(
                                'DEBUG: YouTube controller created successfully for streamed song');
                            await _audioPlayer.stop();
                            setState(() {
                              _currentlyPlayingSongIdx = idx;
                              _selectedSongIdx = idx;
                            });
                            print(
                                'DEBUG: State updated, YouTube player should appear for streamed song');
                          } catch (e) {
                            print(
                                'DEBUG: Error initializing YouTube controller for streamed song: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Error playing YouTube video: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  if (_selectedSongIdx == idx &&
                      isYouTube &&
                      _youtubeController != null)
                    Builder(
                      builder: (context) {
                        print(
                            'DEBUG: Building YouTube player for streamed song index: $idx');
                        print(
                            'DEBUG: Controller is null: ${_youtubeController == null}');
                        return YoutubePlayer(
                          controller: _youtubeController!,
                          aspectRatio: 16 / 9,
                          showVideoProgressIndicator: true,
                          progressIndicatorColor: Colors.blueAccent,
                          onReady: () {
                            print(
                                'DEBUG: YouTube player onReady called for streamed song');
                            _youtubeController!.play();
                          },
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: LayoutBuilder(
            builder: (context, constraints) {
              // Check if we have enough space for the full title
              final availableWidth = constraints.maxWidth;
              final isSmallScreen = availableWidth < 200; // Lower threshold for small screens

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.video_library,
                      size: isSmallScreen ? 18 : 20,
                    ),
                  ),
                  if (!isSmallScreen) ...[
                    const SizedBox(width: 6),
                    Text(
                      'Content',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          actions: [],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 120),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 4,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.6),
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 60),
                isScrollable: false,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.video_library, size: 22),
                    text: 'Videos',
                  ),
                  const Tab(
                    icon: Icon(Icons.music_note, size: 22),
                    text: 'Music',
                  ),
                  const Tab(
                    icon: Icon(Icons.event, size: 22),
                    text: 'Events',
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _buildVideosTab(),
                _buildSongsTab(),
                _buildEventsTab(),
              ],
            ),
            if (_isUploadingVideo)
              Container(
                color: Colors.black54,
                child: Center(
                  child: AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(value: _uploadProgress / 100),
                        const SizedBox(height: 16),
                        Text('Uploading video... ${_uploadProgress.toStringAsFixed(0)}%'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A).withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            heroTag: 'content_main_fab',
            onPressed: _showAddOptionsMenu,
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            elevation: 0,
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      );
    }
  }
