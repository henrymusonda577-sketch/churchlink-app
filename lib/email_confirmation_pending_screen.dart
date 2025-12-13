import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase/supabase.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/user_service.dart';
import 'facebook_home_screen.dart';
import 'pastor_dashboard.dart';

class EmailConfirmationPendingScreen extends StatefulWidget {
  final String email;
  final File? selectedImage;

  const EmailConfirmationPendingScreen({
    super.key,
    required this.email,
    this.selectedImage,
  });

  @override
  State<EmailConfirmationPendingScreen> createState() => _EmailConfirmationPendingScreenState();
}

class _EmailConfirmationPendingScreenState extends State<EmailConfirmationPendingScreen> {
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    // Listen for auth state changes to detect when email is confirmed
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.tokenRefreshed ||
          event.event == AuthChangeEvent.signedIn) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null && session.user.emailConfirmedAt != null) {
          // Email confirmed, proceed to complete signup
          _completeSignup();
        }
      }
    });
  }

  Future<void> _resendConfirmation() async {
    setState(() => _isResending = true);

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Confirmation email resent. Please check your inbox and spam folder.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend confirmation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _completeSignup() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw Exception('No active session');
      }

      final user = session.user;

      // Get user metadata from signup
      final userMetadata = user.userMetadata ?? {};
      final firstName = userMetadata['first_name'] ?? '';
      final lastName = userMetadata['last_name'] ?? '';
      final positionInChurch = userMetadata['position_in_church'] ?? 'Member';
      final bio = userMetadata['bio'] ?? '';
      final birthday = userMetadata['birthday'];
      final gender = userMetadata['gender'];
      final referrerId = userMetadata['referrer_id'];

      // Determine role based on position in church
      String role = 'Member';
      final position = positionInChurch.toLowerCase();
      if (position.contains('pastor') || position.contains('elder') ||
          position.contains('bishop') || position.contains('apostle') ||
          position.contains('reverend') || position.contains('minister') ||
          position.contains('evangelist') || position.contains('administrator') ||
          position.contains('council')) {
        role = 'pastor';
      }

      // Create full name
      final fullName = '$firstName $lastName';

      // Upload profile picture if selected
      String? profilePictureUrl;
      if (widget.selectedImage != null) {
        final safeId = user.id;
        final fileName = '${safeId}_profile.jpg';
        await Supabase.instance.client.storage
            .from('profile-pictures')
            .upload(fileName, widget.selectedImage!);

        profilePictureUrl = Supabase.instance.client.storage
            .from('profile-pictures')
            .getPublicUrl(fileName);
      }

      // Save user data to database
      final userService = UserService();
      await userService.saveUserInfo(
        name: fullName,
        role: role,
        email: widget.email,
        profilePictureUrl: profilePictureUrl,
        bio: bio,
        relationshipStatus: '',
        positionInChurch: positionInChurch,
        churchName: '',
        birthday: birthday,
        gender: gender,
        referrerId: referrerId,
      );


      // Navigate to appropriate screen based on role
      final leadershipRoles = [
        'pastor',
        'elder',
        'bishop',
        'apostle',
        'reverend',
        'minister',
        'evangelist',
        'church administrator',
        'church council member'
      ];

      final userInfo = {
        'id': user.id,
        'email': user.email,
        'name': fullName,
        'role': role,
        'profile_picture_url': profilePictureUrl,
        'bio': bio,
        'position_in_church': positionInChurch,
        'birthday': birthday,
        'gender': gender,
      };

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email confirmed and account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        if (leadershipRoles.contains(role.toLowerCase())) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PastorDashboard(userInfo: userInfo.map((key, value) => MapEntry(key, value?.toString() ?? ''))),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => FacebookHomeScreen(userInfo: userInfo.map((key, value) => MapEntry(key, value?.toString() ?? ''))),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete signup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _signOut,
        ),
        title: const Text(
          'Confirm Email',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Icon(
                Icons.email,
                size: 80,
                color: Color(0xFF1E3A8A),
              ),
              const SizedBox(height: 24),
              const Text(
                'Check your email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'We sent a confirmation link to',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.email,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text(
                'Click the link in the email to confirm your account. You can close this app and return later.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isResending ? null : _resendConfirmation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: _isResending
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'Resend Confirmation Email',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _signOut,
                child: const Text(
                  'Use different email',
                  style: TextStyle(color: Color(0xFF1877F2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
