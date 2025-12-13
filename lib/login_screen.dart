import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase/supabase.dart';
import 'facebook_home_screen.dart';
import 'signup_screen.dart';
import 'services/user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _showResendConfirmation = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _resendConfirmation() async {
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: _emailController.text.trim().toLowerCase(),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Email login
        final email = _emailController.text.trim().toLowerCase();

        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: _passwordController.text,
        );

        if (response.user != null) {
          // Check if user exists in users table by email, if not, create basic entry
          final userCheck = await Supabase.instance.client
              .from('users')
              .select('id')
              .eq('email', email)
              .maybeSingle();

          if (userCheck == null) {
            // User not in users table, create entry with signup data from metadata
            final userService = UserService();
            final userMetadata = response.user!.userMetadata ?? {};

            final firstName = userMetadata['first_name'] ?? '';
            final lastName = userMetadata['last_name'] ?? '';
            final fullName = firstName.isNotEmpty && lastName.isNotEmpty
                ? '$firstName $lastName'
                : response.user!.email!.split('@')[0];

            final positionInChurch = userMetadata['position_in_church'] ?? 'Member';
            String role = 'Member';
            final position = positionInChurch.toLowerCase();
            if (position.contains('pastor') || position.contains('elder') ||
                position.contains('bishop') || position.contains('apostle') ||
                position.contains('reverend') || position.contains('minister') ||
                position.contains('evangelist') || position.contains('administrator') ||
                position.contains('council')) {
              role = 'pastor';
            }

            await userService.saveUserInfo(
              name: fullName,
              role: role,
              email: email,
              profilePictureUrl: null,
              bio: userMetadata['bio'] ?? '',
              relationshipStatus: '',
              positionInChurch: positionInChurch,
              churchName: '',
              birthday: userMetadata['birthday'],
              gender: userMetadata['gender'],
              referrerId: userMetadata['referrer_id'],
            );
          } else {
            // User exists by email, update the id to match the auth user id
            await Supabase.instance.client
                .from('users')
                .update({'id': response.user!.id})
                .eq('email', email);
          }


          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FacebookHomeScreen()),
          );
        }
      } catch (e) {
        String errorMessage = e.toString();
        bool isEmailNotConfirmed = false;
        if (e.toString().contains('No account found') || e.toString().contains('not registered')) {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        } else if (e.toString().contains('Invalid login credentials')) {
          errorMessage = 'Invalid password. Please check your password.';
        } else if (e.toString().contains('rate limit')) {
          errorMessage = 'Too many requests. Please try again later.';
        } else if (e.toString().contains('Email not confirmed')) {
          errorMessage = 'Please confirm your email first.';
          isEmailNotConfirmed = true;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
          setState(() => _showResendConfirmation = isEmailNotConfirmed);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF60A5FA)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E3A8A).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.church, size: 60, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Welcome Back',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign in to your Church-Link account',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Input fields
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          obscureText: !_isPasswordVisible,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),

                        if (_showResendConfirmation) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _resendConfirmation,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF1E3A8A)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Color(0xFF1E3A8A))
                                  : const Text(
                                      'Resend Confirmation Email',
                                      style: TextStyle(color: Color(0xFF1E3A8A)),
                                    ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignupScreen()),
                            );
                          },
                          child: const Text(
                            "Don't have an account? Sign Up",
                            style: TextStyle(color: Color(0xFF1E3A8A)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}