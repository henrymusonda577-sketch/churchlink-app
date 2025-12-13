import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'services/community_service.dart';
import 'services/post_service.dart';
import 'story_viewer_screen.dart';

class CreatePostScreen extends StatefulWidget {
  final bool showStoryOption;
  final String initialType;
  final String source; // 'home' or 'tiktok'

  const CreatePostScreen({
    super.key,
    this.showStoryOption = false,
    this.initialType = 'general',
    this.source = 'home',
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final CommunityService _communityService = CommunityService();
  final PostService _postService = PostService();
  final ImagePicker _picker = ImagePicker();
  String _selectedType = 'general';
  bool _isLoading = false;
  File? _selectedImage;
  File? _selectedVideo;
  Uint8List? _webImageBytes;
  Uint8List? _webVideoBytes;
  String? _imageUrl;
  String? _videoUrl;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _webImageBytes = bytes;
            _selectedImage = null;
            _selectedVideo = null;
            _webVideoBytes = null;
          });
        } else {
          setState(() {
            _selectedImage = File(pickedFile.path);
            _selectedVideo = null;
            _webImageBytes = null;
            _webVideoBytes = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (kIsWeb) {
          final bytes = file.bytes;
          if (bytes != null) {
            setState(() {
              _webVideoBytes = bytes;
              _selectedVideo = null;
              _selectedImage = null;
              _webImageBytes = null;
            });
          }
        } else {
          final path = file.path;
          if (path != null) {
            final videoFile = File(path);
            // Verify the file exists
            if (await videoFile.exists()) {
              setState(() {
                _selectedVideo = videoFile;
                _selectedImage = null;
                _webImageBytes = null;
                _webVideoBytes = null;
              });
            } else {
              throw Exception('Selected video file does not exist');
            }
          }
        }
      }
    } catch (e) {
      print('Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadFile(dynamic file, String folder) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('DEBUG: No authenticated user for upload');
        return null;
      }

      final supabase = Supabase.instance.client;

      // Check if Supabase client is properly initialized
      if (supabase == null) {
        print('DEBUG: Supabase client not initialized');
        return null;
      }

      // Handle XFile type from image_picker
      if (file is XFile) {
        file = File(file.path);
      }

      // Determine file extension based on file type
      String extension = 'jpg'; // default for images
      if (folder == 'videos' || (file is File && file.path.contains('.'))) {
        if (file is File) {
          extension = file.path.split('.').last.toLowerCase();
        } else if (file is Uint8List) {
          // For videos, assume mp4 if no extension available
          extension = 'mp4';
        }
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${user.id}.$extension';

      Uint8List fileBytes;
      if (file is File) {
        fileBytes = await file.readAsBytes();
      } else if (file is Uint8List) {
        fileBytes = file;
      } else if (file is XFile) {
        fileBytes = await file.readAsBytes();
      } else {
        throw Exception('Unsupported file type: ${file.runtimeType}');
      }

      // Use the correct bucket based on file type
      final bucketName = folder == 'videos' ? 'videos' : 'posts';
      print('DEBUG: Uploading to bucket: $bucketName, file: $fileName');

      await supabase.storage.from(bucketName).uploadBinary(fileName, fileBytes);
      final downloadUrl = supabase.storage.from(bucketName).getPublicUrl(fileName);

      print('DEBUG: Upload successful, URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading file: $e');
      print('DEBUG: Upload error details: ${e.toString()}');
      return null;
    }
  }

  Future<void> _createPost() async {
    print('DEBUG: _createPost called');
    print('DEBUG: Content: "${_contentController.text.trim()}"');
    print('DEBUG: Selected type: $_selectedType');
    print('DEBUG: Selected image: ${_selectedImage != null}');
    print('DEBUG: Selected video: ${_selectedVideo != null}');
    print('DEBUG: Web image bytes: ${_webImageBytes != null}');
    print('DEBUG: Web video bytes: ${_webVideoBytes != null}');

    // Check authentication
    final user = Supabase.instance.client.auth.currentUser;
    print('DEBUG: Current user: ${user?.id ?? "null"}');
    print('DEBUG: User email: ${user?.email ?? "null"}');

    if (user == null) {
      print('DEBUG: No authenticated user, cannot create post');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to create a post')),
        );
      }
      return;
    }

    if (_contentController.text.trim().isEmpty &&
        _selectedImage == null &&
        _selectedVideo == null &&
        _webImageBytes == null &&
        _webVideoBytes == null) {
      print('DEBUG: No content to post, returning early');
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('DEBUG: Starting file uploads');

      // Upload image if selected
      if (_selectedImage != null) {
        print('DEBUG: Uploading selected image');
        _imageUrl = await _uploadFile(_selectedImage!, 'images');
        print('DEBUG: Image upload result: $_imageUrl');
        if (_imageUrl == null) throw Exception('Failed to upload image');
      } else if (_webImageBytes != null) {
        print('DEBUG: Uploading web image bytes');
        _imageUrl = await _uploadFile(_webImageBytes!, 'images');
        print('DEBUG: Web image upload result: $_imageUrl');
        if (_imageUrl == null) throw Exception('Failed to upload image');
      }

      // Upload video if selected
      if (_selectedVideo != null) {
        print('DEBUG: Uploading selected video');
        _videoUrl = await _uploadFile(_selectedVideo!, 'videos');
        print('DEBUG: Video upload result: $_videoUrl');
        if (_videoUrl == null) throw Exception('Failed to upload video');
      } else if (_webVideoBytes != null) {
        print('DEBUG: Uploading web video bytes');
        _videoUrl = await _uploadFile(_webVideoBytes!, 'videos');
        print('DEBUG: Web video upload result: $_videoUrl');
        if (_videoUrl == null) throw Exception('Failed to upload video');
      }

      // Check if user is still authenticated before proceeding
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User session expired during upload');
      }

      print(
          'DEBUG: File uploads completed. Image URL: $_imageUrl, Video URL: $_videoUrl');

      // Check Supabase client initialization
      final supabase = Supabase.instance.client;
      print('DEBUG: Supabase client initialized: ${supabase != null}');

      if (_selectedType == 'story') {
        print('DEBUG: Creating STORY via CommunityService (Supabase) - will appear in stories section');
        // Create story using CommunityService (Supabase) - appears in stories section
        await _communityService.createCommunityPost(
          content: _contentController.text.trim(),
          postType: _selectedType,
          imageUrl: _imageUrl,
          videoUrl: _videoUrl,
        );
        print('DEBUG: Story created successfully');
      } else {
        print('DEBUG: Creating COMMUNITY POST via CommunityService (Supabase) - will appear in main feed, source: ${widget.source}');
        // Create community post using CommunityService (Supabase) - appears in main posts feed
        String postType = _selectedType;
        if (_videoUrl != null && _videoUrl!.isNotEmpty && widget.source != 'tiktok') {
          postType = 'video';
        }
        await _communityService.createCommunityPost(
          content: _contentController.text.trim(),
          postType: postType,
          imageUrl: _imageUrl,
          videoUrl: _videoUrl,
          source: widget.source,
        );
        print('DEBUG: Community post created successfully - check main posts feed');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('DEBUG: Error in _createPost: $e');
      print('DEBUG: Stack trace: ${e.toString()}');

      String errorMessage = 'Error creating post';
      if (e.toString().contains('Failed to upload')) {
        errorMessage = 'Failed to upload media. Please check your connection and try again.';
      } else if (e.toString().contains('session expired')) {
        errorMessage = 'Your session has expired. Please sign in again.';
      } else if (e.toString().contains('permission-denied') || e.toString().contains('row-level security')) {
        errorMessage = 'Permission denied. Please check your account and try again.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your connection and try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1E3A8A),
                  child: Text(
                    (user?.email?[0] ?? 'U').toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  user?.email?.split('@')[0] ?? 'User',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Post Type',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                    value: 'prayer', child: Text('Prayer Request')),
                const DropdownMenuItem(value: 'verse', child: Text('Bible Verse')),
                const DropdownMenuItem(value: 'testimony', child: Text('Testimony')),
                const DropdownMenuItem(value: 'general', child: Text('General')),
                const DropdownMenuItem(value: 'video', child: Text('Video Post')),
                if (widget.showStoryOption)
                  const DropdownMenuItem(value: 'story', child: Text('Story')),
              ],
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            const SizedBox(height: 16),

            // Media selection buttons
            Row(
              children: [
                if (_selectedType != 'video') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showImageSourceDialog,
                      icon: const Icon(Icons.image),
                      label: const Text('Add Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  if (_selectedType == 'story' || _selectedType == 'verse' || _selectedType == 'testimony' || _selectedType == 'general') ...[
                    const SizedBox(width: 8),
                  ],
                ],
                if (_selectedType == 'video' || _selectedType == 'story' || _selectedType == 'verse' || _selectedType == 'testimony' || _selectedType == 'general') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.video_library),
                      label: const Text('Add Video'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Display selected media
            if (_selectedImage != null || _webImageBytes != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Stack(
                  children: [
                    _selectedImage != null
                        ? Image.file(
                            _selectedImage!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Image.memory(
                            _webImageBytes!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: () => setState(() {
                          _selectedImage = null;
                          _webImageBytes = null;
                        }),
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (_selectedVideo != null || _webVideoBytes != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Stack(
                  children: [
                    Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.black,
                      child: const Center(
                        child: Icon(
                          Icons.video_library,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: () => setState(() {
                          _selectedVideo = null;
                          _webVideoBytes = null;
                        }),
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Share with your community...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
