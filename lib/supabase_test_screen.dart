import 'package:flutter/material.dart';
import 'supabase_service.dart';
import 'widgets/zambian_phone_input.dart';

class SupabaseTestScreen extends StatefulWidget {
  const SupabaseTestScreen({super.key});

  @override
  State<SupabaseTestScreen> createState() => _SupabaseTestScreenState();
}

class _SupabaseTestScreenState extends State<SupabaseTestScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _subscribeToUsers();
  }

  void _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await SupabaseService.fetchUsers();
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  void _subscribeToUsers() {
    SupabaseService.subscribeToUsers().listen((users) {
      setState(() => _users = users);
    });
  }

  void _addUser() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and email are required')),
      );
      return;
    }

    final success = await SupabaseService.insertUser(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text.isEmpty ? null : _phoneController.text,
    );

    if (success) {
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User added successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add user')),
      );
    }
  }

  void _deleteAllUsers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ DANGER ZONE ⚠️'),
        content: const Text(
          'This will permanently delete ALL users and ALL their data (posts, stories, badges, etc.) from the database.\n\n'
          'This action CANNOT be undone!\n\n'
          'Are you absolutely sure you want to proceed?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE ALL USERS'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    setState(() => _isLoading = true);

    try {
      final result = await SupabaseService.deleteAllUsersCompletely();

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully deleted ${result['deletedCount']} users'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the user list
        _loadUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to delete users: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase Test'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Add User Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New User',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ZambianPhoneInput(
                      controller: _phoneController,
                      labelText: 'Phone (Optional)',
                      validator: null, // Make it optional by overriding the default validator
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _addUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Add User'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Users List
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Users List (Real-time)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _loadUsers,
                            icon: const Icon(Icons.refresh),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _deleteAllUsers,
                            icon: const Icon(Icons.delete_forever, color: Colors.white),
                            label: const Text('DELETE ALL USERS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _users.isEmpty
                                ? const Center(child: Text('No users found'))
                                : ListView.builder(
                                    itemCount: _users.length,
                                    itemBuilder: (context, index) {
                                      final user = _users[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: const Color(0xFF1E3A8A),
                                          child: Text(
                                            user['name']?[0]?.toUpperCase() ?? 'U',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ),
                                        title: Text(user['name'] ?? 'Unknown'),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(user['email'] ?? ''),
                                            if (user['phone'] != null)
                                              Text(user['phone']),
                                          ],
                                        ),
                                        trailing: IconButton(
                                          onPressed: () async {
                                            // Show confirmation dialog
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Delete User'),
                                                content: Text('Are you sure you want to delete ${user['name']}? This will permanently remove the user and all their data.'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(context).pop(false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.of(context).pop(true),
                                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirmed == true) {
                                              final success = await SupabaseService.deleteUserCompletely(user['id'].toString());
                                              if (success) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('User deleted successfully')),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Failed to delete user. Check console for details.')),
                                                );
                                              }
                                            }
                                          },
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}