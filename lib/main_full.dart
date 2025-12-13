import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'facebook_home_screen.dart';
import 'pastor_dashboard.dart';
import 'services/video_service.dart';
import 'services/prayer_service.dart';
import 'services/notification_service.dart';
import 'services/presence_service.dart';
import 'services/video_firebase_service.dart';
import 'services/user_service.dart';
import 'services/call_manager.dart';
import 'services/theme_provider.dart';
import 'sign_in.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    
    final notificationService = NotificationService();
    await notificationService.initialize();

    final presenceService = PresenceService();
    presenceService.initialize();

    final videoFirebaseService = VideoFirebaseService();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => VideoService()),
          ChangeNotifierProvider(create: (_) => PrayerService()),
          Provider<NotificationService>.value(value: notificationService),
          Provider<PresenceService>.value(value: presenceService),
          Provider<VideoFirebaseService>.value(value: videoFirebaseService),
          ChangeNotifierProvider(create: (_) => CallManager()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const ChurchLinkFullApp(),
      ),
    );
  } catch (e) {
    runApp(
      MaterialApp(
        title: 'Church-Link',
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class ChurchLinkFullApp extends StatelessWidget {
  const ChurchLinkFullApp({super.key});

  Future<Map<String, dynamic>?> _getUserInfo(User user) async {
    final userService = UserService();
    return await userService.getUserInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Church-Link',
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }

              if (snapshot.hasData && snapshot.data != null) {
                return FutureBuilder<Map<String, dynamic>?>(
                  future: _getUserInfo(snapshot.data!),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const SplashScreen();
                    }

                    final userInfo = userSnapshot.data ?? {};
                    final userInfoString = userInfo.map(
                        (key, value) => MapEntry(key, value?.toString() ?? ''));
                    final role = userInfo['role']?.toLowerCase() ?? 'member';
                    final leadershipRoles = [
                      'pastor', 'elder', 'bishop', 'apostle', 'reverend', 'minister',
                      'evangelist', 'church administrator', 'church council member'
                    ];

                    if (leadershipRoles.contains(role)) {
                      return PastorDashboard(userInfo: userInfoString);
                    } else {
                      return FacebookHomeScreen(userInfo: userInfoString);
                    }
                  },
                );
              } else {
                return const SignInPage();
              }
            },
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}