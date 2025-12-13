import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'services/user_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, String> userInfo;

  const EditProfileScreen({super.key, required this.userInfo});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _relationshipStatusController = TextEditingController();
  final _positionInChurchController = TextEditingController();
  final _churchNameController = TextEditingController();
  final UserService _userService = UserService();
  final ImagePicker _picker = ImagePicker();

  dynamic _selectedImage; // Can be File (mobile) or Uint8List (web)
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.userInfo['name'] ?? '';
    _bioController.text = widget.userInfo['bio'] ?? '';
    _relationshipStatusController.text =
        widget.userInfo['relationship_status'] ??
            widget.userInfo['relationshipStatus'] ??
            '';
    _positionInChurchController.text = widget.userInfo['position_in_church'] ??
        widget.userInfo['positionInChurch'] ??
        '';
    _churchNameController.text =
        widget.userInfo['church_name'] ?? widget.userInfo['churchName'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _relationshipStatusController.dispose();
    _positionInChurchController.dispose();
    _churchNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    print('DEBUG: _pickImage called, kIsWeb: $kIsWeb');
    try {
      // For web, skip permission checks as image_picker_for_web handles this
      if (!kIsWeb) {
        print('DEBUG: Running on mobile, requesting permissions');
        // Request storage permission for gallery access on mobile
        var status = await Permission.photos.request();
        print('DEBUG: Photos permission status: $status');
        if (!status.isGranted) {
          // Fallback to storage permission for older Android versions
          status = await Permission.storage.request();
          print('DEBUG: Storage permission status: $status');
        }
        if (!status.isGranted) {
          print('DEBUG: Permission not granted, showing dialog');
          // Show permission denied dialog
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permission Required'),
              content: const Text(
                'Gallery access is required to select profile pictures. Please grant permission in your device settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          return;
        } else if (status.isPermanentlyDenied) {
          print('DEBUG: Permission permanently denied, showing settings dialog');
          // Show settings dialog for permanent denial
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permission Required'),
              content: const Text(
                'Gallery access has been permanently denied. Please enable it in your device settings to select profile pictures.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          return;
        }
      } else {
        print('DEBUG: Running on web, skipping permission checks');
      }

      print('DEBUG: Calling _picker.pickImage');
      // Proceed with image picking (works on both web and mobile)
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      print('DEBUG: pickImage returned: ${image != null ? 'XFile with path: ${image.path}, name: ${image.name}' : 'null'}');

      if (image != null) {
        print('DEBUG: Image selected, processing file');
        if (kIsWeb) {
          // On web, get the bytes directly from XFile
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImage = bytes;
          });
          print('DEBUG: _selectedImage set to Uint8List with length: ${bytes.length}');
        } else {
          // On mobile, create File from path
          setState(() {
            _selectedImage = File(image.path);
          });
          print('DEBUG: _selectedImage set to File with path: ${image.path}');
        }
        // Profile picture selected successfully
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image selected successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('DEBUG: Image picker returned null');
        // Image picker returned null - show error
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gallery selection cancelled or failed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error in _pickImage: $e');
      print('DEBUG: Error stack trace: ${StackTrace.current}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      // Check if running on web - camera not supported
      if (kIsWeb) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Camera Not Available'),
            content: const Text(
              'Camera access is not supported in web browsers. Please use the gallery option to select a profile picture.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Request camera permission
      final status = await Permission.camera.request();
      if (status.isGranted) {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 80,
        );
        if (image != null) {
          setState(() {
            _selectedImage = File(image.path);
          });
          // Photo taken successfully
        } else {
          // Image picker returned null - show error
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera capture cancelled or failed'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (status.isDenied) {
        // Show permission denied dialog
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Camera access is required to take profile pictures. Please grant permission in your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      } else if (status.isPermanentlyDenied) {
        // Show settings dialog for permanent denial
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Camera access has been permanently denied. Please enable it in your device settings to take profile pictures.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      } else {
        // Handle other permission states (restricted, etc.)
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Camera access is restricted. Please check your device settings and grant permission to take profile pictures.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error taking photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Update user info including new fields
      await _userService.saveUserInfo(
        name: _nameController.text.trim(),
        role: widget.userInfo['role'] ?? 'Member',
        email: widget.userInfo['email'] ?? '',
        bio: _bioController.text.trim(),
        relationshipStatus: _relationshipStatusController.text.trim(),
        positionInChurch: _positionInChurchController.text.trim(),
        churchName: _churchNameController.text.trim(),
      );

      // Update the profile screen with new data
      if (mounted) {
        Navigator.of(context).pop({
          'name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'relationship_status': _relationshipStatusController.text.trim(),
          'position_in_church': _positionInChurchController.text.trim(),
          'church_name': _churchNameController.text.trim(),
        });
      }

      // Update profile picture if selected
      if (_selectedImage != null) {
        print('DEBUG: Uploading profile picture, type: ${_selectedImage.runtimeType}');
        // Use the new uploadProfilePicture method that returns moderation result
        final uploadResult =
            await _userService.uploadProfilePicture(_selectedImage!);

        print('DEBUG EditProfileScreen._saveChanges: Upload result: $uploadResult');

        if (uploadResult['success'] == true) {
          // If upload succeeded, update profile picture URL
          final uploadedUrl = uploadResult['url'] as String?;
          if (uploadedUrl != null) {
            print('DEBUG EditProfileScreen._saveChanges: Updating profile picture URL to: $uploadedUrl');
            await _userService.updateProfilePicture(uploadedUrl);
            print('DEBUG EditProfileScreen._saveChanges: Profile picture URL updated successfully');
          }
        } else {
          // If upload failed due to moderation, show alert with reason
          final moderationResult =
              uploadResult['moderationResult'] as Map<String, dynamic>?;
          if (moderationResult != null &&
              moderationResult['isAppropriate'] == false) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Profile Picture Not Approved'),
                content: Text(
                  moderationResult['reason'] ??
                      'Your profile picture was flagged as inappropriate. Please choose another image.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } else {
            // Generic error message
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Upload Failed'),
                content: const Text(
                  'Failed to upload profile picture. Please try again later.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ImageProvider? _getBackgroundImage() {
    if (_selectedImage != null) {
      if (_selectedImage is File) {
        return FileImage(_selectedImage as File);
      } else {
        return MemoryImage(_selectedImage as Uint8List);
      }
    } else if (widget.userInfo['profile_picture_url'] != null) {
      return NetworkImage(widget.userInfo['profile_picture_url']!);
    }
    return null;
  }

  String _getAvatarLetter() {
    final name = widget.userInfo['name'];
    if (name != null && name.isNotEmpty && name.trim().isNotEmpty) {
      final firstChar = name.trim()[0].toUpperCase();
      // Avoid showing 'U' if the first letter happens to be 'U'
      return firstChar != 'U'
          ? firstChar
          : (name.length > 1 ? name[1].toUpperCase() : 'A');
    }
    return 'A'; // Default fallback
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        title: Text('Edit Profile', style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Color(0xFF1877F2),
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Color(0xFF1877F2),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile picture section
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _getBackgroundImage(),
                      child: _selectedImage == null &&
                              widget.userInfo['profile_picture_url'] == null
                          ? Text(
                              _getAvatarLetter(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 40,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Theme.of(context).textTheme.bodyLarge?.color
                                    : Colors.grey,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1877F2),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => Container(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title: const Text('Choose from Gallery'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickImage();
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.camera_alt),
                                      title: const Text('Take Photo'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _takePhoto();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Form fields
            Container(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Name field
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                    ),

                    // Bio field
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _bioController,
                        decoration: InputDecoration(
                          labelText: 'Bio',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        maxLines: 3,
                      ),
                    ),

                    // Relationship Status field
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _relationshipStatusController,
                        decoration: InputDecoration(
                          labelText: 'Relationship Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),

                    // Position in Church field
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _positionInChurchController,
                        decoration: InputDecoration(
                          labelText: 'Position in Church',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),

                    // Church Name field
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _churchNameController,
                        decoration: InputDecoration(
                          labelText: 'Church Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),

                    // Role display (read-only)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.surface.withOpacity(0.5)
                              : Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        initialValue: widget.userInfo['role'] ?? 'Member',
                      ),
                    ),

                    // Email display (read-only)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.surface.withOpacity(0.5)
                              : Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        initialValue:
                            widget.userInfo['email'] ?? 'Not provided',
                      ),
                    ),

                    // Phone display (read-only)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: TextFormField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Phone',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.surface.withOpacity(0.5)
                              : Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        initialValue:
                            widget.userInfo['phone'] ?? 'Not provided',
                      ),
                    ),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1877F2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
