import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/payment_config.dart';

final Int64List vibrationPatternList = Int64List.fromList([0, 1000, 500, 1000]);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamController<Map<String, dynamic>> _messageStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream =>
      _messageStreamController.stream;

  Future<void> initialize() async {
    await _requestPermissions();
    await _setupLocalNotifications();
    await _setupRealtimeNotifications();
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) {
      print('Running on web - notification permissions handled by browser');
      return;
    }

    if (Platform.isIOS) {
      // iOS permissions are handled by flutter_local_notifications
      print(
          'iOS notification permissions will be requested when showing first notification');
    } else if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (status.isDenied) {
        print('Notification permission denied');
      }
    }
  }

  Future<void> _setupLocalNotifications() async {
    if (kIsWeb) {
      print('Running on web - local notifications not supported');
      return;
    }

    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final payloadMap = Map<String, dynamic>.from(
              json.decode(response.payload!),
            );
            _handleNotificationClick(payloadMap);
          } catch (e) {
            print('Error parsing notification payload: $e');
          }
        }
      },
    );

    // Create notification channel with custom sound
    await _createNotificationChannel();
  }

  Future<void> _setupRealtimeNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Listen to real-time notifications from Supabase
    _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((data) {
          print('Received notifications from stream: ${data.length}');
          final unreadNotifications = data.where((n) => n['is_read'] == false).toList();
          print('Unread notifications: ${unreadNotifications.length}');
          for (final notification in unreadNotifications) {
            _showLocalNotification(notification);
            _messageStreamController.add(notification);
          }
        });
  }

  Future<void> _createNotificationChannel() async {
    if (kIsWeb) return;

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'church_link_channel',
      'Church Link Notifications',
      description: 'Notifications for church activities and messages',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showLocalNotification(Map<String, dynamic> notification) async {
    if (kIsWeb) {
      print(
          'Web notification: ${notification['title']} - ${notification['message']}');
      return;
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'church_link_channel',
      'Church Link Notifications',
      channelDescription: 'Notifications for church activities and messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification['id'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification['title'] ?? 'New Notification',
      notification['message'] ?? 'You have a new notification',
      notificationDetails,
      payload: json.encode(notification['data'] ?? {}),
    );
  }

  void _handleNotificationClick(Map<String, dynamic>? data) {
    if (data != null) {
      print('Notification data: $data');
      // TODO: Handle navigation based on notification data
    }
  }

  Future<void> showCustomNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    print('Sending custom notification: $title - $body');

    if (kIsWeb) {
      print('Web custom notification: $title - $body');
      return;
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'custom_channel',
      'Custom Notifications',
      channelDescription: 'Custom notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: data != null ? json.encode(data) : null,
    );
  }

  // Send notification to specific users
  Future<void> sendNotificationToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      if (userIds.isEmpty) {
        throw Exception('User IDs list cannot be empty');
      }

      if (title.trim().isEmpty) {
        throw Exception('Notification title cannot be empty');
      }

      if (body.trim().isEmpty) {
        throw Exception('Notification body cannot be empty');
      }

      final validUserIds = userIds.where((id) => id.trim().isNotEmpty).toList();
      if (validUserIds.isEmpty) {
        throw Exception('No valid user IDs found');
      }

      print('Sending notification to ${validUserIds.length} users:');
      print('Title: $title');
      print('Body: $body');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Insert notifications for each user
      final notifications = validUserIds
          .map((userId) => {
                'user_id': userId,
                'type': 'custom',
                'from_user_id': currentUser.id,
                'title': title,
                'message': body,
                'data': data ?? {},
                'is_read': false,
                'created_at': DateTime.now().toIso8601String(),
              })
          .toList();

      await _supabase.from('notifications').insert(notifications);

      print('Notification sent successfully to ${validUserIds.length} users');
    } catch (e) {
      print('Error sending notifications: $e');
      throw Exception('Failed to send notifications: $e');
    }
  }

  // Send notification to all church members
  Future<void> sendNotificationToChurchMembers({
    required String churchId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get all church members
      final membersResponse = await _supabase
          .from('church_members')
          .select('user_id')
          .eq('church_id', churchId);

      final userIds = membersResponse
          .map<String>((member) => member['user_id'] as String)
          .toList();

      if (userIds.isNotEmpty) {
        await sendNotificationToUsers(
          userIds: userIds,
          title: title,
          body: body,
          data: data,
        );
      }
    } catch (e) {
      print('Error sending notification to church members: $e');
      throw e;
    }
  }

  // Send push notification (for live streams, urgent announcements)
  Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      await _supabase.from('notifications').insert({
        'user_id': userId,
        'type': 'push',
        'from_user_id': currentUser.id,
        'title': title,
        'message': body,
        'data': data ?? {},
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Also show local notification if it's for current user
      if (userId == currentUser.id) {
        await showCustomNotification(
          title: title,
          body: body,
          data: data,
        );
      }
    } catch (e) {
      print('Error sending push notification: $e');
      throw e;
    }
  }

  // Get notifications for current user
  Stream<List<Map<String, dynamic>>> getNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) return Stream.value([]);

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
  }

  // Get unread notifications count
  Future<int> getUnreadNotificationsCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      print('Error getting unread notifications count: $e');
      return 0;
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
      throw e;
    }
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      print('Error marking all notifications as read: $e');
      throw e;
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      print('Error deleting notification: $e');
      throw e;
    }
  }

  // Subscribe to topic (for church-wide notifications)
  Future<void> subscribeToChurch(String churchId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('notification_subscriptions').upsert({
        'user_id': user.id,
        'church_id': churchId,
        'subscribed_at': DateTime.now().toIso8601String(),
      });

      print('Subscribed to church notifications: $churchId');
    } catch (e) {
      print('Error subscribing to church: $e');
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromChurch(String churchId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('notification_subscriptions')
          .delete()
          .eq('user_id', user.id)
          .eq('church_id', churchId);

      print('Unsubscribed from church notifications: $churchId');
    } catch (e) {
      print('Error unsubscribing from church: $e');
    }
  }

  // Send scheduled notification (for events, reminders)
  Future<void> scheduleNotification({
    required String userId,
    required String title,
    required String body,
    required DateTime scheduledTime,
    Map<String, dynamic>? data,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      await _supabase.from('scheduled_notifications').insert({
        'user_id': userId,
        'from_user_id': currentUser.id,
        'title': title,
        'message': body,
        'data': data ?? {},
        'scheduled_for': scheduledTime.toIso8601String(),
        'is_sent': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('Notification scheduled for: $scheduledTime');
    } catch (e) {
      print('Error scheduling notification: $e');
      throw e;
    }
  }

  // Get notification preferences
  Future<Map<String, bool>> getNotificationPreferences() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return {};

      final response = await _supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) {
        // Return default preferences
        return {
          'prayers': true,
          'events': true,
          'messages': true,
          'live_streams': true,
          'church_updates': true,
        };
      }

      return Map<String, bool>.from(response);
    } catch (e) {
      print('Error getting notification preferences: $e');
      return {};
    }
  }

  // Update notification preferences
  Future<void> updateNotificationPreferences(
      Map<String, bool> preferences) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('notification_preferences').upsert({
        'user_id': user.id,
        ...preferences,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating notification preferences: $e');
      throw e;
    }
  }

  // Send donation confirmation email using Resend
  Future<bool> sendDonationConfirmationEmail({
    required String recipientEmail,
    required String recipientName,
    required double amount,
    required String churchName,
    required String transactionId,
    required double platformFee,
    required double churchAmount,
  }) async {
    try {
      if (PaymentConfig.resendApiKey.isEmpty || PaymentConfig.resendApiKey == "your-resend-api-key-here") {
        print('Resend API key not configured, skipping email notification');
        return false;
      }

      final emailHtml = _buildDonationConfirmationEmailHtml(
        recipientName: recipientName,
        amount: amount,
        churchName: churchName,
        transactionId: transactionId,
        platformFee: platformFee,
        churchAmount: churchAmount,
      );

      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer ${PaymentConfig.resendApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': PaymentConfig.fromEmail,
          'to': [recipientEmail],
          'subject': 'Donation Confirmation - Church Link',
          'html': emailHtml,
        }),
      );

      if (response.statusCode == 200) {
        print('Donation confirmation email sent successfully to $recipientEmail');
        return true;
      } else {
        print('Failed to send donation confirmation email: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending donation confirmation email: $e');
      return false;
    }
  }

  // Send donation notification to church pastor
  Future<bool> sendDonationNotificationToPastor({
    required String pastorEmail,
    required String pastorName,
    required String donorName,
    required double amount,
    required String churchName,
    required String transactionId,
    required double platformFee,
    required double churchAmount,
  }) async {
    try {
      if (PaymentConfig.resendApiKey.isEmpty || PaymentConfig.resendApiKey == "your-resend-api-key-here") {
        print('Resend API key not configured, skipping pastor notification email');
        return false;
      }

      final emailHtml = _buildPastorDonationNotificationEmailHtml(
        pastorName: pastorName,
        donorName: donorName,
        amount: amount,
        churchName: churchName,
        transactionId: transactionId,
        platformFee: platformFee,
        churchAmount: churchAmount,
      );

      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer ${PaymentConfig.resendApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': PaymentConfig.fromEmail,
          'to': [pastorEmail],
          'subject': 'New Donation Received - $churchName',
          'html': emailHtml,
        }),
      );

      if (response.statusCode == 200) {
        print('Donation notification email sent successfully to pastor $pastorEmail');
        return true;
      } else {
        print('Failed to send donation notification email to pastor: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending donation notification email to pastor: $e');
      return false;
    }
  }

  String _buildDonationConfirmationEmailHtml({
    required String recipientName,
    required double amount,
    required String churchName,
    required String transactionId,
    required double platformFee,
    required double churchAmount,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Donation Confirmation</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #1E3A8A; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { background: #f9f9f9; padding: 20px; border-radius: 0 0 8px 8px; }
        .amount { font-size: 24px; font-weight: bold; color: #1E3A8A; text-align: center; margin: 20px 0; }
        .details { background: white; padding: 15px; border-radius: 5px; margin: 15px 0; }
        .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Thank You for Your Donation!</h1>
        </div>
        <div class="content">
            <p>Dear $recipientName,</p>
            <p>Thank you for your generous donation to $churchName. Your support helps us continue our mission and serve our community.</p>

            <div class="amount">
                Donation Amount: ZMW ${amount.toStringAsFixed(2)}
            </div>

            <div class="details">
                <h3>Donation Breakdown:</h3>
                <p><strong>Total Donated:</strong> ZMW ${amount.toStringAsFixed(2)}</p>
                <p><strong>Platform Fee (10%):</strong> ZMW ${platformFee.toStringAsFixed(2)}</p>
                <p><strong>Church Receives (90%):</strong> ZMW ${churchAmount.toStringAsFixed(2)}</p>
                <p><strong>Transaction ID:</strong> $transactionId</p>
                <p><strong>Church:</strong> $churchName</p>
            </div>

            <p>Your donation has been processed securely and the funds will be transferred to $churchName within 24-48 hours.</p>

            <p>If you have any questions, please don't hesitate to contact us.</p>

            <p>God bless,<br>The Church Link Team</p>
        </div>
        <div class="footer">
            <p>This is an automated message from Church Link. Please do not reply to this email.</p>
        </div>
    </div>
</body>
</html>
''';
  }

  String _buildPastorDonationNotificationEmailHtml({
    required String pastorName,
    required String donorName,
    required double amount,
    required String churchName,
    required String transactionId,
    required double platformFee,
    required double churchAmount,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>New Donation Received</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #1E3A8A; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { background: #f9f9f9; padding: 20px; border-radius: 0 0 8px 8px; }
        .amount { font-size: 24px; font-weight: bold; color: #1E3A8A; text-align: center; margin: 20px 0; }
        .details { background: white; padding: 15px; border-radius: 5px; margin: 15px 0; }
        .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>New Donation Received!</h1>
        </div>
        <div class="content">
            <p>Dear Pastor $pastorName,</p>
            <p>Great news! $churchName has received a new donation.</p>

            <div class="amount">
                ZMW ${amount.toStringAsFixed(2)}
            </div>

            <div class="details">
                <h3>Donation Details:</h3>
                <p><strong>Donor:</strong> $donorName</p>
                <p><strong>Total Amount:</strong> ZMW ${amount.toStringAsFixed(2)}</p>
                <p><strong>Platform Fee (10%):</strong> ZMW ${platformFee.toStringAsFixed(2)}</p>
                <p><strong>Church Receives (90%):</strong> ZMW ${churchAmount.toStringAsFixed(2)}</p>
                <p><strong>Transaction ID:</strong> $transactionId</p>
                <p><strong>Church:</strong> $churchName</p>
            </div>

            <p>The funds will be transferred to your church's payout account within 24-48 hours.</p>

            <p>You can view all donation details and analytics in your pastor dashboard.</p>

            <p>God bless,<br>The Church Link Team</p>
        </div>
        <div class="footer">
            <p>This is an automated message from Church Link. Please do not reply to this email.</p>
        </div>
    </div>
</body>
</html>
''';
  }

  void dispose() {
    _messageStreamController.close();
  }
}
