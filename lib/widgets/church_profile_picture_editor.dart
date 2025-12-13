import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

typedef OnImageSelected = Future<void> Function(XFile imageFile);

class ChurchProfilePictureEditor extends StatefulWidget {
  final String? imageUrl;
  final OnImageSelected onImageSelected;

  const ChurchProfilePictureEditor({
    Key? key,
    required this.imageUrl,
    required this.onImageSelected,
  }) : super(key: key);

  @override
  _ChurchProfilePictureEditorState createState() =>
      _ChurchProfilePictureEditorState();
}

class _ChurchProfilePictureEditorState
    extends State<ChurchProfilePictureEditor> {
  XFile? _selectedImage;

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
    print('DEBUG ChurchProfilePictureEditor._pickImage: Starting image pick from source: $source');
    try {
      final picker = ImagePicker();
      print('DEBUG ChurchProfilePictureEditor._pickImage: Created ImagePicker instance');
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1000,
        maxHeight: 1000,
      );
      print('DEBUG ChurchProfilePictureEditor._pickImage: ImagePicker returned: ${pickedFile != null ? 'file selected' : 'null'}');

      if (pickedFile != null) {
        print('DEBUG ChurchProfilePictureEditor._pickImage: File path: ${pickedFile.path}');
        print('DEBUG ChurchProfilePictureEditor._pickImage: File name: ${pickedFile.name}');
        setState(() {
          _selectedImage = pickedFile;
        });
        print('DEBUG ChurchProfilePictureEditor._pickImage: Calling onImageSelected callback');
        await widget.onImageSelected(pickedFile);
        print('DEBUG ChurchProfilePictureEditor._pickImage: onImageSelected callback completed');
      } else {
        print('DEBUG ChurchProfilePictureEditor._pickImage: No file was selected');
      }
    } catch (e) {
      print('DEBUG ChurchProfilePictureEditor._pickImage: Error occurred: $e');
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
    return Stack(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundImage: _selectedImage != null
              ? (_selectedImage!.path.startsWith('http')
                  ? NetworkImage(_selectedImage!.path)
                  : FileImage(File(_selectedImage!.path))) as ImageProvider
              : (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                  ? NetworkImage(widget.imageUrl!) as ImageProvider
                  : null,
          backgroundColor: const Color(0xFF1E3A8A),
          child: (widget.imageUrl == null || widget.imageUrl!.isEmpty) &&
                  _selectedImage == null
              ? Text(
                  'C',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _showImageSourceDialog,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.add,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
