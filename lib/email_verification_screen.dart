import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/user_service.dart';
import 'facebook_home_screen.dart';
import 'sign_in.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String positionInChurch;
  final String bio;
  final File? selectedImage;
  final String? birthday;
  final String? gender;
  final String? referrerId;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.positionInChurch,
    required this.bio,
    this.selectedImage,
    this.birthday,
    this.gender,
    this.referrerId,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isLoading = false;
  bool _isResending = false;
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _verificationId;
  int _remainingSeconds = 600; // 10 minutes
  bool _isCodeExpired = false;

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Timer? _timer;

  void _startCountdownTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _isCodeExpired = true;
            timer.cancel();
          }
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);

    try {
      if (widget.email.trim().isEmpty) {
        throw Exception('No email provided for resend');
      }

      debugPrint('[EmailVerification] Resending verification code for: ${widget.email.trim()}');

      // Call the send-code function without providing a code (it will generate one)
      final response = await Supabase.instance.client.functions.invoke(
        'send-code',
        body: {
          'email': widget.email.trim(),
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to resend verification code: ${response.data['error'] ?? 'Unknown error'}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code resent successfully. Please check your inbox and spam folder.'),
            backgroundColor: Colors.green,
          ),
        );
        // Reset timer and expired state
        setState(() {
          _remainingSeconds = 600;
          _isCodeExpired = false;
        });
        _startCountdownTimer();
      }

      debugPrint('[EmailVerification] Successfully resent verification code');
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to resend verification code';
        final err = e.toString().toLowerCase();
        if (err.contains('too many')) {
          errorMessage = 'Too many requests. Please try again later.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    bool verificationSuccessful = false;

    try {
      final code = _codeController.text.trim();

      // Call the verify-code function
      final response = await Supabase.instance.client.functions.invoke(
        'verify-code',
        body: {
          'email': widget.email.trim(),
          'code': code,
        },
      );

      print('DEBUG: Verify response status: ${response.status}');
      print('DEBUG: Verify response data: ${response.data}');

      if (response.status == 200) {
        verificationSuccessful = true;
        print('DEBUG: Verification successful');
      } else {
        // Verification failed - show detailed error and stop
        verificationSuccessful = false;
        final errorMessage = response.data?['error'] ?? 'Verification failed';
        print('DEBUG: Verification failed: $errorMessage');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification failed: $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      // Verification failed - show detailed error and stop
      verificationSuccessful = false;
      print('DEBUG: Verification exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    // Only proceed with sign up if verification was successful
    if (!verificationSuccessful) {
      setState(() => _isLoading = false);
      return;
    }

    // Validate payload before signup
    final email = widget.email.trim();
    final password = widget.password;

    if (email.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw Exception('Invalid email format');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    try {

      // Log the exact payload
      print('DEBUG: Signup payload: {email: "$email", password: "${password.replaceAll(RegExp(r'.'), '*')}"}');

      // Now create the user account with Supabase Auth using HTTP directly to get response body
      print('DEBUG: Attempting signup for $email');
      final url = Uri.parse('https://dsdbbqdcreyevjwysvzq.supabase.co/auth/v1/signup');
      final response = await http.post(
        url,
        headers: {
          'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRzZGJicWRjcmV5ZXZqd3lzdnpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyNzkyMzgsImV4cCI6MjA3NTg1NTIzOH0.tamqNsRjuII2WcF6QmT0eOpD0zIHPj7dv8vIFSEu8eg',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('DEBUG: Signup HTTP status: ${response.statusCode}');
      print('DEBUG: Signup HTTP body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['user']?['id'] == null) {
          throw Exception('Failed to create user account - no user returned');
        }
        // User created successfully
      } else {
        // Handle error
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error_description'] ?? errorData['msg'] ?? 'Signup failed';
        throw Exception('Signup failed: $errorMessage');
      }

      // Update user metadata
      await Supabase.instance.client.auth.updateUser(UserAttributes(
        data: {
          'first_name': widget.firstName,
          'last_name': widget.lastName,
          'position_in_church': widget.positionInChurch,
        }
      ));

      // Sign the user in
      final signInResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (signInResponse.user == null) {
        throw Exception('Failed to sign in after verification');
      }

      // Determine role based on position in church
      String role = 'Member';
      final position = widget.positionInChurch.toLowerCase();
      if (position.contains('pastor') || position.contains('elder') ||
          position.contains('bishop') || position.contains('apostle') ||
          position.contains('reverend') || position.contains('minister') ||
          position.contains('evangelist') || position.contains('administrator') ||
          position.contains('council')) {
        role = 'pastor';
      }

      // Create full name
      final fullName = '${widget.firstName} ${widget.lastName}';

      // Upload profile picture if selected
      String? profilePictureUrl;
      if (widget.selectedImage != null) {
        final safeId = signInResponse.user!.id;
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
        bio: widget.bio,
        relationshipStatus: '',
        positionInChurch: widget.positionInChurch,
        churchName: '',
        birthday: widget.birthday,
        gender: widget.gender,
        referrerId: widget.referrerId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified and account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FacebookHomeScreen()),
        );
      }
    } catch (e) {
      print('DEBUG: Signup error: $e');
      final err = e.toString().toLowerCase();

      // If user already exists, try signing in instead
      if (err.contains('already registered') || err.contains('user already registered')) {
        print('DEBUG: User already exists, attempting sign in');
        try {
          final signInResponse = await Supabase.instance.client.auth.signInWithPassword(
            email: email,
            password: password,
          );

          if (signInResponse.user != null) {
            print('DEBUG: Sign in successful for existing user');
            // Proceed with the rest of the flow
            // Update user metadata if needed
            await Supabase.instance.client.auth.updateUser(UserAttributes(
              data: {
                'first_name': widget.firstName,
                'last_name': widget.lastName,
                'position_in_church': widget.positionInChurch,
              }
            ));

            // Continue with profile setup...
            // (rest of the code after signup)
            // Determine role based on position in church
            String role = 'Member';
            final position = widget.positionInChurch.toLowerCase();
            if (position.contains('pastor') || position.contains('elder') ||
                position.contains('bishop') || position.contains('apostle') ||
                position.contains('reverend') || position.contains('minister') ||
                position.contains('evangelist') || position.contains('administrator') ||
                position.contains('council')) {
              role = 'pastor';
            }

            // Create full name
            final fullName = '${widget.firstName} ${widget.lastName}';

            // Prepare signup data
            String? profilePictureUrl;

            // Upload profile picture if selected
            if (widget.selectedImage != null) {
              final safeId = signInResponse.user!.id;
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
              bio: widget.bio,
              relationshipStatus: '',
              positionInChurch: widget.positionInChurch,
              churchName: '',
              birthday: widget.birthday,
              gender: widget.gender,
              referrerId: widget.referrerId,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Signed in successfully!'),
                  backgroundColor: Colors.green,
                ),
              );

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const FacebookHomeScreen()),
              );
            }
            return; // Exit the function
          } else {
            throw Exception('Failed to sign in existing user');
          }
        } catch (signInError) {
          print('DEBUG: Sign in error for existing user: $signInError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Account exists but sign in failed. Please try signing in manually.\nDetails: $signInError'), backgroundColor: Colors.red, duration: Duration(seconds: 15)),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      // Other errors
      if (mounted) {
        String errorMessage = 'Account creation failed';
        if (err.contains('email not confirmed')) {
          errorMessage = 'Email not confirmed. Please check your email and confirm.';
        } else if (err.contains('invalid login credentials')) {
          errorMessage = 'Invalid credentials. Please try again.';
        } else if (err.contains('weak password')) {
          errorMessage = 'Password is too weak. Please choose a stronger password.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$errorMessage\nDetails: $e'), backgroundColor: Colors.red, duration: Duration(seconds: 15)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Verify Email',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.email, size: 80, color: Color(0xFF1E3A8A)),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter the 6-digit code sent to',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    widget.email,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Verification Code',
                    border: OutlineInputBorder(),
                    hintText: 'Enter 6-digit code',
                  ),
                  keyboardType: TextInputType.text,
                  maxLength: 6,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the verification code';
                    }
                    if (value.length != 6) {
                      return 'Code must be 6 digits';
                    }
                    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                      return 'Code must contain only numbers';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _isCodeExpired
                        ? 'Code expired. Please resend.'
                        : 'Code expires in ${_formatTime(_remainingSeconds)}',
                    style: TextStyle(
                      color: _isCodeExpired ? Colors.red : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isCodeExpired) ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCodeExpired ? Colors.grey : const Color(0xFF1877F2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Verify Email',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _isResending ? null : _resendCode,
                    child: Text(
                      _isResending ? 'Sending...' : 'Resend Code',
                      style: const TextStyle(color: Color(0xFF1877F2)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}