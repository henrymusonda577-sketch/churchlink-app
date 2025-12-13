import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';

class PresenceService with WidgetsBindingObserver {
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isInitialized = false;

  // Singleton pattern
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  void initialize() {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;

    // Set user online when service is initialized
    _setOnline();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOffline();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _setOffline();
        break;
      default:
        break;
    }
  }

  Future<bool> _shouldShowOnlineStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('show_online_status') ?? true;
    } catch (e) {
      print('Error checking online status setting: $e');
      return true; // Default to true if error
    }
  }

  Future<void> _setOnline() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final shouldShow = await _shouldShowOnlineStatus();
        if (shouldShow) {
          await _userService.setUserOnline();
          // Reduced logging for production
          if (false) print('User set to online: ${user.uid}');
        } else {
          print('User online status disabled, not updating presence');
        }
      }
    } catch (e) {
      print('Error setting user online: $e');
    }
  }

  Future<void> _setOffline() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final shouldShow = await _shouldShowOnlineStatus();
        if (shouldShow) {
          await _userService.setUserOffline();
          // Reduced logging for production
          if (false) print('User set to offline: ${user.uid}');
        } else {
          print('User online status disabled, not updating presence');
        }
      }
    } catch (e) {
      print('Error setting user offline: $e');
    }
  }

  // Manual control methods (for testing or specific use cases)
  Future<void> setOnline() async {
    await _setOnline();
  }

  Future<void> setOffline() async {
    await _setOffline();
  }

  // Get presence for a specific user
  Future<Map<String, dynamic>?> getUserPresence(String userId) {
    return _userService.getUserPresence(userId);
  }

  // Stream presence for real-time updates
  Stream<Map<String, dynamic>?> getUserPresenceStream(String userId) {
    return _userService.getUserPresenceStream(userId);
  }
}
