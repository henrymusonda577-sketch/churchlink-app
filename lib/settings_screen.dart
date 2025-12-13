import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, String> userInfo;

  const SettingsScreen({super.key, required this.userInfo});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SharedPreferences _prefs;

  // Notification preferences
  bool _pushNotificationsEnabled = true;
  bool _postNotificationsEnabled = true;
  bool _messageNotificationsEnabled = true;
  bool _churchNotificationsEnabled = true;
  bool _verseNotificationsEnabled = true;

  // Privacy settings
  bool _profileVisibleToAll = true;
  bool _showOnlineStatus = true;
  bool _allowTagging = true;

  // Security settings
  bool _twoFactorEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotificationsEnabled = _prefs.getBool('push_notifications') ?? true;
      _postNotificationsEnabled = _prefs.getBool('post_notifications') ?? true;
      _messageNotificationsEnabled =
          _prefs.getBool('message_notifications') ?? true;
      _churchNotificationsEnabled =
          _prefs.getBool('church_notifications') ?? true;
      _verseNotificationsEnabled =
          _prefs.getBool('verse_notifications') ?? true;
      _profileVisibleToAll = _prefs.getBool('profile_visible') ?? true;
      _showOnlineStatus = _prefs.getBool('show_online_status') ?? true;
      _allowTagging = _prefs.getBool('allow_tagging') ?? true;
      _twoFactorEnabled = _prefs.getBool('two_factor') ?? false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // Account Section
          _buildSectionHeader('Account'),
          _buildListTile(
            icon: Icons.person,
            title: 'Edit Profile',
            subtitle: 'Update your personal information',
            onTap: () => _navigateToEditProfile(),
          ),
          _buildListTile(
            icon: Icons.security,
            title: 'Security Settings',
            subtitle: 'Password, 2FA, and account security',
            onTap: () => _showSecuritySettings(),
          ),
          _buildListTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Settings',
            subtitle: 'Control your privacy and data sharing',
            onTap: () => _showPrivacySettings(),
          ),

          const Divider(),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          _buildSwitchTile(
            icon: Icons.notifications,
            title: 'Push Notifications',
            subtitle: 'Receive push notifications',
            value: _pushNotificationsEnabled,
            onChanged: (value) {
              setState(() => _pushNotificationsEnabled = value);
              _saveSetting('push_notifications', value);
            },
          ),
          if (_pushNotificationsEnabled) ...[
            _buildSwitchTile(
              icon: Icons.post_add,
              title: 'Post Notifications',
              subtitle: 'Notifications for new posts and updates',
              value: _postNotificationsEnabled,
              onChanged: (value) {
                setState(() => _postNotificationsEnabled = value);
                _saveSetting('post_notifications', value);
              },
            ),
            _buildSwitchTile(
              icon: Icons.message,
              title: 'Message Notifications',
              subtitle: 'Notifications for new messages',
              value: _messageNotificationsEnabled,
              onChanged: (value) {
                setState(() => _messageNotificationsEnabled = value);
                _saveSetting('message_notifications', value);
              },
            ),
            _buildSwitchTile(
              icon: Icons.church,
              title: 'Church Notifications',
              subtitle: 'Notifications from your church',
              value: _churchNotificationsEnabled,
              onChanged: (value) {
                setState(() => _churchNotificationsEnabled = value);
                _saveSetting('church_notifications', value);
              },
            ),
            _buildSwitchTile(
              icon: Icons.book,
              title: 'Daily Verse Notifications',
              subtitle: 'Daily verse of the day reminders',
              value: _verseNotificationsEnabled,
              onChanged: (value) {
                setState(() => _verseNotificationsEnabled = value);
                _saveSetting('verse_notifications', value);
              },
            ),
          ],


          // Privacy Section
          _buildSectionHeader('Privacy'),
          _buildSwitchTile(
            icon: Icons.visibility,
            title: 'Profile Visible to All',
            subtitle: 'Allow everyone to see your profile',
            value: _profileVisibleToAll,
            onChanged: (value) {
              setState(() {
                _profileVisibleToAll = value;
              });
              _saveSetting('profile_visible', value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.circle,
            title: 'Show Online Status',
            subtitle: 'Show when you are online',
            value: _showOnlineStatus,
            onChanged: (value) {
              setState(() {
                _showOnlineStatus = value;
              });
              _saveSetting('show_online_status', value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.tag,
            title: 'Allow Tagging',
            subtitle: 'Allow others to tag you in posts',
            value: _allowTagging,
            onChanged: (value) {
              setState(() {
                _allowTagging = value;
              });
              _saveSetting('allow_tagging', value);
            },
          ),

          const Divider(),

          // Logout
          _buildListTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            onTap: _showLogoutDialog,
            textColor: Colors.red,
            iconColor: Colors.red,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? const Color(0xFF1E3A8A)),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  void _navigateToEditProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(userInfo: widget.userInfo),
      ),
    );
  }

  void _showSecuritySettings() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Security Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Two-Factor Authentication'),
                value: _twoFactorEnabled,
                onChanged: (value) {
                  setState(() {
                    _twoFactorEnabled = value;
                  });
                  _saveSetting('two_factor', value);
                },
              ),
              // Additional security settings can be added here
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Privacy Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Profile Visible to All'),
                value: _profileVisibleToAll,
                onChanged: (value) {
                  setState(() {
                    _profileVisibleToAll = value;
                  });
                  _saveSetting('profile_visible', value);
                },
              ),
              SwitchListTile(
                title: const Text('Show Online Status'),
                value: _showOnlineStatus,
                onChanged: (value) {
                  setState(() {
                    _showOnlineStatus = value;
                  });
                  _saveSetting('show_online_status', value);
                },
              ),
              SwitchListTile(
                title: const Text('Allow Tagging'),
                value: _allowTagging,
                onChanged: (value) {
                  setState(() {
                    _allowTagging = value;
                  });
                  _saveSetting('allow_tagging', value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }


  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _logout,
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }
}
