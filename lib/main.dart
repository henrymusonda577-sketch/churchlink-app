import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/supabase_config.dart';
import 'package:flutter/foundation.dart';

import 'facebook_home_screen.dart';
import 'pastor_dashboard.dart';
import 'services/user_service.dart';
import 'services/church_service.dart';
import 'services/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/call_manager.dart';
import 'widgets/call_screen.dart';
import 'sign_in.dart';
import 'email_confirmation_pending_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();



  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // Initialize notification service
  await NotificationService().initialize();

  runApp(const ChurchLinkApp());
}

class ChurchLinkApp extends StatefulWidget {
  const ChurchLinkApp({super.key});

  @override
  State<ChurchLinkApp> createState() => _ChurchLinkAppState();
}

class _ChurchLinkAppState extends State<ChurchLinkApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _supabaseInitialized = false;
  bool _initializationFailed = false;

  @override
  void initState() {
    super.initState();
    _initializeSupabase();
  }

  Future<void> _initializeSupabase() async {
    try {
      // Supabase is already initialized in main()
      // Test the connection by checking if we can access the client
      final client = Supabase.instance.client;
      print('Supabase client initialized successfully');
      print('Supabase URL: ${SupabaseConfig.supabaseUrl}');
      print('Anon Key: ${SupabaseConfig.supabaseAnonKey.substring(0, 20)}...');

      setState(() {
        _supabaseInitialized = true;
      });
    } catch (e) {
      print('Supabase initialization failed: $e');
      setState(() {
        _initializationFailed = true;
      });
      // Wait 3 seconds then proceed anyway
      await Future.delayed(const Duration(seconds: 3));
      setState(() {
        _supabaseInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: _ChurchLinkAppState.build called, _supabaseInitialized: $_supabaseInitialized');
    if (!_supabaseInitialized) {
      return MaterialApp(
        title: 'Church-Link',
        home: Scaffold(
          backgroundColor: const Color(0xFF1E3A8A),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.church,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Church-Link',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 20),
                Text(
                  _initializationFailed
                      ? 'Connection failed, proceeding...'
                      : 'Connecting...',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    print('DEBUG: Creating MultiProvider with CallManager');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) {
          print('DEBUG: Creating CallManager provider');
          final callManager = CallManager(navigatorKey: navigatorKey);
          // Don't initialize here - will initialize after auth
          return callManager;
        }),
      ],
      child: AllChurchesApp(navigatorKey: navigatorKey),
    );
  }
}

class AllChurchesApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const AllChurchesApp({super.key, required this.navigatorKey});

  @override
  State<AllChurchesApp> createState() => _AllChurchesAppState();
}

class _AllChurchesAppState extends State<AllChurchesApp> {

  Future<Map<String, dynamic>?> _getUserInfo(User user) async {
    print('DEBUG main.dart _getUserInfo: Getting user info for ${user.email}');
    try {
      final userService = UserService();
      final churchService = ChurchService();
      final userInfo = await userService.getUserInfo();
      print('DEBUG main.dart _getUserInfo: User info from service: $userInfo');
      if (userInfo != null) {
        // Check if role needs to be updated based on position
        final currentRole = userInfo['role']?.toLowerCase() ?? 'member';
        final positionInChurch = userInfo['position_in_church'] ?? '';
        if (currentRole == 'member') {
          final position = positionInChurch.toLowerCase();
          if (position.contains('pastor') || position.contains('elder') ||
              position.contains('bishop') || position.contains('apostle') ||
              position.contains('reverend') || position.contains('minister') ||
              position.contains('evangelist') || position.contains('administrator') ||
              position.contains('council')) {
            // Update role to 'pastor'
            await userService.updateUserProfile({'role': 'pastor'});
            userInfo['role'] = 'pastor';
          }
        }

        return userInfo;
      } else {
        // Check if user has a church (is pastor)
        try {
          final churches = await Supabase.instance.client
              .from('churches')
              .select()
              .eq('pastor_id', user.id);
          if (churches.isNotEmpty) {
            final churchData = churches.first;
            // User is pastor, save to users table
            await userService.saveUserInfo(
              name: user.userMetadata?['name'] ?? user.email?.split('@')[0] ?? 'User',
              role: 'pastor',
              email: user.email ?? '',
              positionInChurch: 'pastor',
              churchName: churchData['church_name'],
            );
            return await userService.getUserInfo();
          }
        } catch (e) {
          print('Error checking for user church: $e');
        }
        // Check shared preferences for signup data
        final prefs = await SharedPreferences.getInstance();
        final firstName = prefs.getString('first_name');
        if (firstName != null) {
          // Save user data
          final lastName = prefs.getString('last_name') ?? '';
          final fullName = '$firstName $lastName';
          final bio = prefs.getString('bio') ?? '';
          final birthday = prefs.getString('birthday');
          final gender = prefs.getString('gender');
          final referrerId = prefs.getString('referrer_id');
          final positionInChurch = prefs.getString('position_in_church') ?? 'Member';

          // Determine role from position
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
            email: user.email ?? '',
            profilePictureUrl: '',
            bio: bio,
            relationshipStatus: '',
            positionInChurch: positionInChurch,
            churchName: '',
            birthday: birthday,
            gender: gender,
            referrerId: referrerId,
          );
          // Update user metadata
          await Supabase.instance.client.auth.updateUser(UserAttributes(
            data: {
              'first_name': firstName,
              'last_name': lastName,
              'position_in_church': positionInChurch,
            }
          ));
          // Clear prefs
          await prefs.remove('first_name');
          await prefs.remove('last_name');
          await prefs.remove('position_in_church');
          await prefs.remove('bio');
          await prefs.remove('birthday');
          await prefs.remove('gender');
          await prefs.remove('referrer_id');
          await prefs.remove('role');
          // Return the saved info
          return await userService.getUserInfo();
        } else {
          // If email is confirmed but no data, try to save from metadata
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null && session.user.emailConfirmedAt != null) {
            final userMetadata = session.user.userMetadata ?? {};
            final firstName = userMetadata['first_name'] ?? '';
            final lastName = userMetadata['last_name'] ?? '';
            final positionInChurch = userMetadata['position_in_church'] ?? 'Member';
            final bio = userMetadata['bio'] ?? '';
            final birthday = userMetadata['birthday'];
            final gender = userMetadata['gender'];
            final referrerId = userMetadata['referrer_id'];

            String role = 'Member';
            final position = positionInChurch.toLowerCase();
            if (position.contains('pastor') || position.contains('elder') ||
                position.contains('bishop') || position.contains('apostle') ||
                position.contains('reverend') || position.contains('minister') ||
                position.contains('evangelist') || position.contains('administrator') ||
                position.contains('council')) {
              role = 'pastor';
            }

            final fullName = '$firstName $lastName';

            await userService.saveUserInfo(
              name: fullName,
              role: role,
              email: user.email ?? '',
              profilePictureUrl: '',
              bio: bio,
              relationshipStatus: '',
              positionInChurch: positionInChurch,
              churchName: '',
              birthday: birthday,
              gender: gender,
              referrerId: referrerId,
            );

            // Return the saved info
            return await userService.getUserInfo();
          } else {
            // Check metadata for role even without confirmed email
            final userMetadata = user.userMetadata ?? {};
            final positionInChurch = userMetadata['position_in_church'] ?? '';
            String role = 'member';
            final position = positionInChurch.toLowerCase();
            if (position.contains('pastor') || position.contains('elder') ||
                position.contains('bishop') || position.contains('apostle') ||
                position.contains('reverend') || position.contains('minister') ||
                position.contains('evangelist') || position.contains('administrator') ||
                position.contains('council')) {
              role = 'pastor';
            }

            return {
              'id': user.id,
              'email': user.email,
              'name': user.email?.split('@')[0] ?? 'User',
              'role': role,
              'phone': user.phone,
            };
          }
        }
      }
    } catch (e) {
      print('Error getting user info in main.dart: $e');
      // Return basic user info if service fails
      return {
        'id': user.id,
        'email': user.email,
        'name': user.email?.split('@')[0] ?? 'User',
        'role': 'member',
        'phone': user.phone,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Consumer<CallManager>(
          builder: (context, callManager, child) {
              print('DEBUG: Consumer<CallManager> builder called - state: ${callManager.currentCallState}');

            return MaterialApp(
              title: 'Church-Link',
              theme: themeProvider.lightTheme,
              darkTheme: themeProvider.darkTheme,
              themeMode:
                  themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              navigatorKey: widget.navigatorKey,
              home: StreamBuilder<AuthState>(
                stream: Supabase.instance.client.auth.onAuthStateChange,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return FutureBuilder(
                      future: Future.delayed(const Duration(seconds: 5)),
                      builder: (context, timeoutSnapshot) {
                        if (timeoutSnapshot.connectionState ==
                            ConnectionState.done) {
                          return const SignInPage();
                        }
                        return const _LoadingScreen();
                      },
                    );
                  }

                  if (snapshot.hasError) {
                    print('Auth error: ${snapshot.error}');
                    return const SignInPage();
                  }

                  final session = Supabase.instance.client.auth.currentSession;
                  if (session != null) {
                    // Check if email is confirmed
                    if (session.user.emailConfirmedAt != null) {
                      // Email confirmed, navigate to appropriate screen based on role
                      return FutureBuilder<Map<String, dynamic>?>(
                        future: _getUserInfo(session.user),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const _LoadingScreen();
                          }

                          final userInfo = userSnapshot.data ?? {};
                          print('DEBUG main.dart build: User info: $userInfo');
                          final userInfoString = userInfo.map(
                              (key, value) => MapEntry(key, value?.toString() ?? ''));
                          final role = userInfo['role']?.toLowerCase() ?? 'member';
                          print('DEBUG main.dart build: Detected role: $role');
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

                          print('DEBUG main.dart build: Leadership roles: $leadershipRoles');
                          print('DEBUG main.dart build: Role in leadership: ${leadershipRoles.contains(role)}');

                          // Initialize CallManager after user authentication
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final callManager = Provider.of<CallManager>(context, listen: false);
                            if (callManager.currentCallState == CallState.idle) {
                              print('DEBUG: Initializing CallManager after authentication');
                              callManager.initialize();
                            }
                          });

                          if (leadershipRoles.contains(role)) {
                            print('DEBUG main.dart build: Navigating to PastorDashboard');
                            return PastorDashboard(userInfo: userInfoString);
                          } else {
                            print('DEBUG main.dart build: Navigating to FacebookHomeScreen');
                            return FacebookHomeScreen(userInfo: userInfoString);
                          }
                        },
                      );
                    } else {
                      // Email not confirmed, show confirmation pending screen
                      return EmailConfirmationPendingScreen(
                        email: session.user.email ?? '',
                        selectedImage: null, // No image available in this context
                      );
                    }
                  } else {
                    // User is not signed in, show sign in screen
                    return const SignInPage();
                  }
                },
              ),
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }

}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.church,
              color: Colors.white,
              size: 80,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            const Text(
              'Church-Link',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connecting...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
