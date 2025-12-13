import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'services/church_service.dart';
import 'services/user_service.dart';
import 'facebook_home_screen.dart';
import 'widgets/zambian_phone_input.dart';

class CreateChurchScreen extends StatefulWidget {
  final Map<String, String> userInfo;

  const CreateChurchScreen({super.key, required this.userInfo});

  @override
  State<CreateChurchScreen> createState() => _CreateChurchScreenState();
}

class _CreateChurchScreenState extends State<CreateChurchScreen> {
  final ChurchService _churchService = ChurchService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController churchNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController denominationController = TextEditingController();
  final TextEditingController pastorNameController = TextEditingController();
  final TextEditingController pastorPhoneController = TextEditingController();
  final TextEditingController pastorEmailController = TextEditingController();
  XFile? _selectedImage;
  bool _isAuthorized = false;
  bool _isLoadingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  @override
  void dispose() {
    churchNameController.dispose();
    descriptionController.dispose();
    addressController.dispose();
    phoneController.dispose();
    emailController.dispose();
    websiteController.dispose();
    denominationController.dispose();
    pastorNameController.dispose();
    pastorPhoneController.dispose();
    pastorEmailController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthorization() async {
    try {
      final userService = UserService();
      final userInfo = await userService.getUserInfo();
      print('DEBUG CreateChurch: userInfo: $userInfo');
      print('DEBUG CreateChurch: role: ${userInfo?['role']}, position: ${userInfo?['position_in_church']}');
      if (userInfo != null && (userInfo['role']?.toLowerCase() == 'pastor' || userInfo['position_in_church'] == 'Pastor')) {
        print('DEBUG CreateChurch: Authorized');
        setState(() {
          _isAuthorized = true;
          _isLoadingAuth = false;
        });
      } else {
        print('DEBUG CreateChurch: Not authorized');
        setState(() {
          _isAuthorized = false;
          _isLoadingAuth = false;
        });
      }
    } catch (e) {
      print('DEBUG CreateChurch: Error: $e');
      setState(() {
        _isAuthorized = false;
        _isLoadingAuth = false;
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickImage(ImageSource.gallery);
                },
              ),
              if (!kIsWeb) // Only show camera option on non-web platforms
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take Photo'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickImage(ImageSource.camera);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1000,
        maxHeight: 1000,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile;
        });
      }
    } catch (e) {
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAuth) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Create Church'),
          backgroundColor: const Color(0xFF1E3A8A),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: const Color(0xFF1E3A8A),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock,
                  size: 64,
                  color: Colors.red,
                ),
                SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Only users with the "Pastor" position can create churches.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Church'),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: _selectedImage != null
                        ? (_selectedImage!.path.startsWith('http')
                            ? NetworkImage(_selectedImage!.path)
                            : kIsWeb
                                ? NetworkImage(_selectedImage!.path) // Web paths are blob URLs
                                : FileImage(File(_selectedImage!.path))) as ImageProvider
                        : null,
                    backgroundColor: const Color(0xFF1E3A8A),
                    child: _selectedImage == null
                        ? const Icon(Icons.add_a_photo,
                            size: 40, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: churchNameController,
                  decoration: const InputDecoration(labelText: 'Church Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter church name';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an address';
                    }
                    return null;
                  },
                ),
                ZambianPhoneInput(
                  controller: phoneController,
                  labelText: 'Phone',
                ),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an email';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: websiteController,
                  decoration: const InputDecoration(labelText: 'Website'),
                ),
                TextFormField(
                  controller: denominationController,
                  decoration: const InputDecoration(labelText: 'Denomination'),
                ),
                TextFormField(
                  controller: pastorNameController,
                  decoration: const InputDecoration(labelText: 'Pastor Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter pastor name';
                    }
                    return null;
                  },
                ),
                ZambianPhoneInput(
                  controller: pastorPhoneController,
                  labelText: 'Pastor Phone',
                ),
                TextFormField(
                  controller: pastorEmailController,
                  decoration: const InputDecoration(labelText: 'Pastor Email'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter pastor email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final churchName = churchNameController.text.trim();
                      final description = descriptionController.text.trim();
                      final address = addressController.text.trim();
                      final phone = phoneController.text.trim();
                      final email = emailController.text.trim();
                      final website = websiteController.text.trim();
                      final denomination = denominationController.text.trim();
                      final pastorName = pastorNameController.text.trim();
                      final pastorPhone = pastorPhoneController.text.trim();
                      final pastorEmail = pastorEmailController.text.trim();

                      String? imageUrl;
                      if (_selectedImage != null) {
                        imageUrl = await _churchService.uploadChurchLogo(
                            _selectedImage!, 'temp_church_id');
                      }
                      await _churchService.createChurch(
                        churchName: churchName,
                        description: description,
                        address: address,
                        phone: phone,
                        email: email,
                        website: website,
                        denomination: denomination,
                        pastorName: pastorName,
                        pastorPhone: pastorPhone,
                        pastorEmail: pastorEmail,
                        churchLogoUrl: imageUrl,
                      );
                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Church created successfully!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );

                      // Navigate to home screen after a short delay
                      Future.delayed(const Duration(seconds: 2), () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => FacebookHomeScreen(
                              userInfo: {
                                'uid': widget.userInfo['uid'] ?? '',
                                'name': widget.userInfo['name'] ?? '',
                                'email': widget.userInfo['email'] ?? '',
                                'role': widget.userInfo['role'] ?? 'member',
                              },
                            ),
                          ),
                        );
                      });
                    }
                  },
                  child: const Text('Create Church'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
