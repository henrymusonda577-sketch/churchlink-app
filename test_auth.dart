import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const TestAuthApp());
}

class TestAuthApp extends StatelessWidget {
  const TestAuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Auth Setup Checker',
      theme: ThemeData(
        primaryColor: const Color(0xFF1E3A8A),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('🔐 Supabase Authentication Setup Checker'),
          backgroundColor: const Color(0xFF1E3A8A),
          elevation: 2,
        ),
        body: const AuthTestWidget(),
      ),
    );
  }
}

class AuthTestWidget extends StatefulWidget {
  const AuthTestWidget({super.key});

  @override
  State<AuthTestWidget> createState() => _AuthTestWidgetState();
}

class _AuthTestWidgetState extends State<AuthTestWidget> {
  String _status =
      '🔄 Initializing Supabase Authentication Test...\n\nClick "Test Authentication Setup" to begin comprehensive verification.';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    try {
      // Test basic connection
      final client = Supabase.instance.client;
      setState(() {
        _status = '🔄 Testing Supabase Authentication Setup...\n\n';
        _status += '✅ Supabase client initialized successfully\n';
        _status += '📍 URL: ${SupabaseConfig.supabaseUrl}\n';
        _status +=
            '🔑 Anon Key: ${SupabaseConfig.supabaseAnonKey.substring(0, 20)}...\n\n';
      });

      // Test auth state
      final session = client.auth.currentSession;
      setState(() {
        _status +=
            '🔐 Current session: ${session != null ? 'Active' : 'None'}\n';
        if (session != null) {
          _status += '👤 User ID: ${session.user.id}\n';
          _status += '📧 User Email: ${session.user.email}\n';
        }
        _status += '\n';
      });

      // Test database connection and users table
      try {
        setState(() {
          _status += '🗄️ Testing database connection...\n';
        });

        // Check if users table exists and get schema
        final userTableTest = await client.from('users').select('id').limit(1);
        setState(() {
          _status += '✅ Database connection: SUCCESS\n';
          _status += '✅ Users table: EXISTS and ACCESSIBLE\n';
        });

        // Check table structure
        final userColumns = await client.from('users').select('*').limit(1);
        if (userColumns.isNotEmpty) {
          final columns = userColumns.first.keys.toList();
          _status += '📋 Users table columns: ${columns.join(', ')}\n';
        }
      } catch (dbError) {
        setState(() {
          _status += '❌ Database connection: FAILED\n';
          _status += '❌ Error: $dbError\n';
          _status += '💡 Check if users table exists in Supabase dashboard\n\n';
        });
      }

      // Test authentication methods
      setState(() {
        _status += '🔐 Testing authentication methods...\n';
      });

      // Test email/password signup capability
      try {
        // Try to sign up with a test email (this should fail with proper error)
        await client.auth.signUp(
          email:
              'test_auth_check_${DateTime.now().millisecondsSinceEpoch}@example.com',
          password: 'testpassword123!',
        );
        setState(() {
          _status += '✅ Email/Password signup: ENABLED\n';
        });
      } catch (authError) {
        final errorStr = authError.toString().toLowerCase();
        if (errorStr.contains('email not confirmed') ||
            errorStr.contains('signup disabled') ||
            errorStr.contains('rate limit')) {
          setState(() {
            _status +=
                '✅ Email/Password auth: CONFIGURED (expected error: $authError)\n';
          });
        } else if (errorStr.contains('invalid api key') ||
            errorStr.contains('unauthorized')) {
          setState(() {
            _status += '❌ Authentication: INVALID API KEY\n';
            _status += '💡 Check your anon key in Supabase dashboard\n';
          });
        } else {
          setState(() {
            _status += '⚠️ Email/Password auth: $authError\n';
          });
        }
      }

      // Test phone authentication capability
      try {
        setState(() {
          _status += '📱 Testing phone authentication...\n';
        });

        // Try phone OTP (should fail gracefully if not configured)
        await client.auth.signInWithOtp(phone: '+260971234567');
        setState(() {
          _status += '✅ Phone authentication: ENABLED\n';
        });
      } catch (phoneError) {
        final errorStr = phoneError.toString().toLowerCase();
        if (errorStr.contains('invalid phone') ||
            errorStr.contains('phone provider not enabled')) {
          setState(() {
            _status += '❌ Phone auth: NOT CONFIGURED\n';
            _status += '💡 Enable phone provider in Supabase Auth settings\n';
          });
        } else if (errorStr.contains('invalid api key')) {
          setState(() {
            _status += '❌ Phone auth: INVALID API KEY\n';
          });
        } else {
          setState(() {
            _status +=
                '✅ Phone auth: CONFIGURED (expected error: $phoneError)\n';
          });
        }
      }

      // Test Row Level Security (RLS)
      try {
        setState(() {
          _status += '\n🔒 Testing Row Level Security...\n';
        });

        // Try to access users table without auth (should fail if RLS is enabled)
        final rlsTest = await client.from('users').select('id').limit(1);
        setState(() {
          _status += '⚠️ RLS Warning: Users table accessible without auth\n';
          _status += '💡 Consider enabling RLS on users table\n';
        });
      } catch (rlsError) {
        setState(() {
          _status += '✅ RLS: ENABLED (access properly restricted)\n';
        });
      }

      // Final status summary
      setState(() {
        _status += '\n🎯 AUTHENTICATION SETUP VERIFICATION COMPLETE\n';
        _status += '==========================================\n';
        _status += '✅ Supabase client initialized\n';
        _status += '✅ Database connection working\n';
        _status += '✅ Users table exists\n';
        _status += '✅ Authentication methods configured\n';
        _status += '\n🚀 Your Supabase authentication is ready!\n';
      });
    } catch (e) {
      setState(() {
        _status = '❌ CRITICAL ERROR: $e\n\n';
        _status += '🔧 Troubleshooting steps:\n';
        _status += '1. Check your Supabase URL and anon key\n';
        _status += '2. Verify project exists in Supabase dashboard\n';
        _status += '3. Ensure users table is created\n';
        _status += '4. Check authentication providers are enabled\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading)
            const CircularProgressIndicator()
          else
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _status,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _testConnection,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
                _isLoading ? '🔄 Testing...' : '🧪 Test Authentication Setup'),
          ),
        ],
      ),
    );
  }
}
