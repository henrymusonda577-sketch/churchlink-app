import 'package:flutter/material.dart';
import 'services/prayer_service.dart';

class PrayerFormScreen extends StatefulWidget {
  final Map<String, String> userInfo;

  const PrayerFormScreen({super.key, required this.userInfo});

  @override
  State<PrayerFormScreen> createState() => _PrayerFormScreenState();
}

class _PrayerFormScreenState extends State<PrayerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _prayerController = TextEditingController();
  bool _isPublic = true;

  @override
  void dispose() {
    _titleController.dispose();
    _prayerController.dispose();
    super.dispose();
  }

  void _submitPrayer() {
    if (_formKey.currentState!.validate()) {
      // Save prayer to the prayer service
      final prayerData = {
        'title': _titleController.text,
        'prayer': _prayerController.text,
        'isPublic': _isPublic,
        'author': widget.userInfo['name'],
        'authorRole': widget.userInfo['role'],
      };
      
      // Add prayer to the service
      PrayerService().addPrayer(prayerData);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isPublic 
            ? 'Prayer posted publicly successfully!' 
            : 'Prayer saved privately successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Prayer'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                                              const Icon(
                          Icons.favorite,
                          size: 40,
                          color: Color(0xFF1E3A8A),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Share Your Prayer',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Write your prayer and share it with the community',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Prayer Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Prayer Title',
                  hintText: 'Enter a title for your prayer',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a prayer title';
                  }
                  if (value.length < 3) {
                    return 'Title must be at least 3 characters long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Prayer Content
              TextFormField(
                controller: _prayerController,
                decoration: const InputDecoration(
                  labelText: 'Your Prayer',
                  hintText: 'Write your prayer here...',
                  prefixIcon: Icon(Icons.edit),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please write your prayer';
                  }
                  if (value.length < 10) {
                    return 'Prayer must be at least 10 characters long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Privacy Toggle
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        _isPublic ? Icons.public : Icons.lock,
                        color: _isPublic ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isPublic ? 'Public Prayer' : 'Private Prayer',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _isPublic 
                                ? 'This prayer will be visible to everyone in the community'
                                : 'This prayer will only be visible to you and church leaders',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPublic,
                        onChanged: (value) {
                          setState(() {
                            _isPublic = value;
                          });
                        },
                        activeColor: const Color(0xFF1E3A8A),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitPrayer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Post Prayer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
