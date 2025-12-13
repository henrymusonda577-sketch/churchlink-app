import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import '../config/payment_config.dart';
import 'church_payout_service.dart';
import 'notification_service.dart';

class DonationService {
    final SupabaseClient _supabase = Supabase.instance.client;
    final ChurchPayoutService _payoutService = ChurchPayoutService();
    final NotificationService _notificationService = NotificationService();

  // Payment gateway credentials from config
  static const String _publicKey = PaymentConfig.flutterwavePublicKey;
  static const String _secretKey = PaymentConfig.flutterwaveSecretKey;
  static const String _encryptionKey = PaymentConfig.flutterwaveEncryptionKey;

  static const String _airtelClientId = PaymentConfig.airtelClientId;
  static const String _airtelClientSecret = PaymentConfig.airtelClientSecret;
  static const String _airtelBaseUrl = PaymentConfig.airtelBaseUrl;

  static const String _mtnApiKey = PaymentConfig.mtnApiKey;
  static const String _mtnApiSecret = PaymentConfig.mtnApiSecret;
  static const String _mtnBaseUrl = PaymentConfig.mtnBaseUrl;
  static const String _mtnSubscriptionKey = PaymentConfig.mtnSubscriptionKey;

  // Company numbers for Airtel and MTN Mobile Money Zambia
  static const String airtelCompanyNumber = '0973644384';
  static const String mtnCompanyNumber = '0964536477';

  Future<Map<String, dynamic>?> initiatePayment({
      required BuildContext context,
      required double amount,
      required String currency,
      required String paymentMethod,
      required String purpose,
      String? donationType,
      String? message,
      String? churchId,
      String? churchName,
      String? pin,
      String? phone,
    }) async {
     final user = _supabase.auth.currentUser;
     if (user == null) {
       throw Exception('User not authenticated');
     }

    // Route to appropriate payment processor based on payment method
    if (paymentMethod.toLowerCase().contains('airtel')) {
      return _processAirtelPayment(
        context: context,
        amount: amount,
        currency: currency,
        purpose: purpose,
        donationType: donationType,
        message: message,
        churchId: churchId,
        churchName: churchName,
        pin: pin,
        phone: phone,
        user: user,
      );
    } else if (paymentMethod.toLowerCase().contains('mtn')) {
      return _processMtnPayment(
        context: context,
        amount: amount,
        currency: currency,
        purpose: purpose,
        donationType: donationType,
        message: message,
        churchId: churchId,
        churchName: churchName,
        pin: pin,
        phone: phone,
        user: user,
      );
    } else {
      // Default to Flutterwave for card payments
      return _processCardPayment(
        context: context,
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
        purpose: purpose,
        donationType: donationType,
        message: message,
        churchId: churchId,
        churchName: churchName,
        user: user,
      );
    }
  }

  Future<String> logDonation({
      required String userId,
      required double amount,
      required String currency,
      required String paymentMethod,
      required String purpose,
      String? donationType,
      String? message,
      required String transactionId,
      String status = 'completed',
      String? churchId,
      String? churchName,
    }) async {
      try {
        final donationData = {
          'user_id': userId,
          'amount': amount,
          'currency': currency,
          'payment_method': paymentMethod,
          'purpose': purpose,
          'donation_type': donationType ?? '',
          'message': message ?? '',
          'transaction_id': transactionId,
          'status': status,
          'church_id': churchId,
          'church_name': churchName,
          'created_at': DateTime.now().toIso8601String(),
        };

        final response = await _supabase
            .from('donations')
            .insert(donationData)
            .select('id')
            .single();

        final donationId = response['id'] as String;

        // Process split payments for church donations
        if (churchId != null && status == 'completed') {
          await _payoutService.processDonationSplit(
            donationId: donationId,
            totalAmount: amount,
            churchId: churchId,
          );
        }

        return donationId;
      } catch (e) {
        print('Error logging donation: $e');
        throw e;
      }
    }

  Future<Map<String, dynamic>?> verifyPayment(String transactionId) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.flutterwave.com/v3/transactions/$transactionId/verify'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to verify payment');
      }
    } catch (e) {
      print('Error verifying payment: $e');
      rethrow;
    }
  }

  // Get Airtel access token
  Future<String> _getAirtelAccessToken() async {
    final response = await http.post(
      Uri.parse('$_airtelBaseUrl/auth/oauth2/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'client_credentials',
        'client_id': _airtelClientId,
        'client_secret': _airtelClientSecret,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['access_token'];
    } else {
      throw Exception('Failed to get Airtel access token: ${response.body}');
    }
  }

  // Process Airtel Money payment
    Future<Map<String, dynamic>?> _processAirtelPayment({
      required BuildContext context,
      required double amount,
      required String currency,
      required String purpose,
      String? donationType,
      String? message,
      String? churchId,
      String? churchName,
      String? pin,
      String? phone,
      required User user,
    }) async {
    try {
      // Validate phone number and PIN
      final phoneNumber = phone ?? user.userMetadata?['phone'] ?? '';
      if (phoneNumber.isEmpty) {
        throw Exception('Phone number is required for Airtel Money payment');
      }
      if (pin == null || pin.isEmpty) {
        throw Exception('PIN is required for Airtel Money payment');
      }

      // Get JWT token for authentication
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('User session not found');
      }

      // Call Supabase Edge Function for Airtel collection
      final response = await _supabase.functions.invoke(
        'airtel-collection',
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: {
          'amount': amount,
          'phoneNumber': phoneNumber.replaceAll('+', ''),
          'description': 'Donation: $purpose${donationType != null ? ' - $donationType' : ''}${message != null ? ' - $message' : ''}',
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        // Log the donation
        final donationId = await logDonation(
          userId: user.id,
          amount: amount,
          currency: currency,
          paymentMethod: 'Airtel Money',
          purpose: purpose,
          donationType: donationType,
          message: message,
          transactionId: data['reference'] ?? 'airtel_${DateTime.now().millisecondsSinceEpoch}',
          status: 'pending',
          churchId: churchId,
          churchName: churchName,
        );

        // Show success message to user
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Payment request sent! Please check your phone and enter your PIN to complete the transaction.'),
              duration: Duration(seconds: 5),
            ),
          );
        }

        return {
          'status': 'success',
          'message': 'Payment initiated successfully',
          'transaction_id': data['reference'],
        };
      } else {
        throw Exception(response.data?['error'] ?? 'Airtel Money payment failed');
      }
    } catch (e) {
      print('Error processing Airtel Money payment: $e');
      rethrow;
    }
  }

  // Get MTN access token
  Future<String> _getMtnAccessToken() async {
    final response = await http.post(
      Uri.parse('$_mtnBaseUrl/collection/token/'),
      headers: {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$_mtnApiKey:$_mtnApiSecret'))}',
        'Ocp-Apim-Subscription-Key': _mtnSubscriptionKey,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['access_token'];
    } else {
      throw Exception('Failed to get MTN access token: ${response.body}');
    }
  }

  // Process MTN Mobile Money payment
    Future<Map<String, dynamic>?> _processMtnPayment({
      required BuildContext context,
      required double amount,
      required String currency,
      required String purpose,
      String? donationType,
      String? message,
      String? churchId,
      String? churchName,
      String? pin,
      String? phone,
      required User user,
    }) async {
    try {
      // Validate phone number and PIN
      final phoneNumber = phone ?? user.userMetadata?['phone'] ?? '';
      if (phoneNumber.isEmpty) {
        throw Exception(
            'Phone number is required for MTN Mobile Money payment');
      }
      if (pin == null || pin.isEmpty) {
        throw Exception('PIN is required for MTN Mobile Money payment');
      }

      // Get JWT token for authentication
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('User session not found');
      }

      // Call Supabase Edge Function for MTN collection
      final response = await _supabase.functions.invoke(
        'mtn-collection',
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: {
          'amount': amount,
          'phoneNumber': phoneNumber.replaceAll('+', ''),
          'description': 'Donation: $purpose${donationType != null ? ' - $donationType' : ''}${message != null ? ' - $message' : ''}',
        },
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        // Log the donation
        final donationId = await logDonation(
          userId: user.id,
          amount: amount,
          currency: currency,
          paymentMethod: 'MTN Mobile Money',
          purpose: purpose,
          donationType: donationType,
          message: message,
          transactionId: data['reference'] ?? 'mtn_${DateTime.now().millisecondsSinceEpoch}',
          status: 'pending',
          churchId: churchId,
          churchName: churchName,
        );

        // Show success message to user
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Payment request sent! Please check your phone and approve the transaction.'),
              duration: Duration(seconds: 5),
            ),
          );
        }

        return {
          'status': 'success',
          'message': 'Payment initiated successfully',
          'transaction_id': data['reference'],
        };
      } else {
        throw Exception(response.data?['error'] ?? 'MTN Mobile Money payment failed');
      }
    } catch (e) {
      print('Error processing MTN Mobile Money payment: $e');
      rethrow;
    }
  }

  // Update donation status (for mobile money confirmations)
  Future<bool> updateDonationStatus(String transactionId, String status) async {
    try {
      await _supabase
          .from('donations')
          .update({'status': status})
          .eq('transaction_id', transactionId);

      // If status is completed and split not processed, process it
      if (status == 'completed') {
        final donation = await _supabase
            .from('donations')
            .select('id, church_id, amount, split_processed, user_id, church_name')
            .eq('transaction_id', transactionId)
            .single();

        if (donation['church_id'] != null && !(donation['split_processed'] ?? false)) {
          await _payoutService.processDonationSplit(
            donationId: donation['id'],
            totalAmount: (donation['amount'] as num).toDouble(),
            churchId: donation['church_id'],
          );
        }

        // Send confirmation emails
        await _sendDonationEmails(donation);
      }

      return true;
    } catch (e) {
      print('Error updating donation status: $e');
      return false;
    }
  }

  // Send donation confirmation emails
  Future<void> _sendDonationEmails(Map<String, dynamic> donation) async {
    try {
      final userId = donation['user_id'] as String;
      final churchId = donation['church_id'] as String?;
      final amount = (donation['amount'] as num).toDouble();
      final churchName = donation['church_name'] as String? ?? 'Church';
      final transactionId = donation['transaction_id'] as String? ?? '';
      final platformFee = (donation['platform_fee'] as num?)?.toDouble() ?? (amount * 0.1);
      final churchAmount = (donation['church_amount'] as num?)?.toDouble() ?? (amount * 0.9);

      // Get donor info
      final donorResponse = await _supabase
          .from('users')
          .select('email, name')
          .eq('id', userId)
          .single();

      final donorEmail = donorResponse['email'] as String?;
      final donorName = donorResponse['name'] as String? ?? 'Donor';

      // Send confirmation email to donor
      if (donorEmail != null) {
        await _notificationService.sendDonationConfirmationEmail(
          recipientEmail: donorEmail,
          recipientName: donorName,
          amount: amount,
          churchName: churchName,
          transactionId: transactionId,
          platformFee: platformFee,
          churchAmount: churchAmount,
        );
      }

      // Send notification email to pastor
      if (churchId != null) {
        final pastorResponse = await _supabase
            .from('churches')
            .select('pastor_id')
            .eq('id', churchId)
            .single();

        final pastorId = pastorResponse['pastor_id'] as String?;

        if (pastorId != null) {
          final pastorInfoResponse = await _supabase
              .from('users')
              .select('email, name')
              .eq('id', pastorId)
              .single();

          final pastorEmail = pastorInfoResponse['email'] as String?;
          final pastorName = pastorInfoResponse['name'] as String? ?? 'Pastor';

          if (pastorEmail != null) {
            await _notificationService.sendDonationNotificationToPastor(
              pastorEmail: pastorEmail,
              pastorName: pastorName,
              donorName: donorName,
              amount: amount,
              churchName: churchName,
              transactionId: transactionId,
              platformFee: platformFee,
              churchAmount: churchAmount,
            );
          }

          // Send in-app notification to pastor
          await _notificationService.sendNotificationToUsers(
            userIds: [pastorId],
            title: 'New Donation Received',
            body: 'Your church received ZMW ${amount.toStringAsFixed(2)} from $donorName. Church gets ZMW ${churchAmount.toStringAsFixed(2)}.',
            data: {
              'type': 'donation',
              'church_id': churchId,
              'amount': amount,
              'church_amount': churchAmount,
              'platform_fee': platformFee,
            },
          );
        }
      }
    } catch (e) {
      print('Error sending donation emails: $e');
      // Don't throw error as this shouldn't break the donation flow
    }
  }

  // Process card payment (Visa/Mastercard) using Flutterwave
    Future<Map<String, dynamic>?> _processCardPayment({
     required BuildContext context,
     required double amount,
     required String currency,
     required String paymentMethod,
     required String purpose,
     String? donationType,
     String? message,
     String? churchId,
     String? churchName,
     required User user,
   }) async {
    final txRef = "CARD_${DateTime.now().millisecondsSinceEpoch}";

    try {
      final customer = Customer(
        name: user.userMetadata?['name'] ?? 'Church App User',
        phoneNumber: user.userMetadata?['phone'] ?? '',
        email: user.email ?? '',
      );

      final flutterwave = Flutterwave(
        publicKey: _publicKey,
        currency: currency,
        redirectUrl: 'https://church-link.app/payment/callback',
        txRef: txRef,
        amount: amount.toString(),
        customer: customer,
        paymentOptions: "card,mobilemoney,ussd",
        customization: Customization(
          title: "Church-Link Donation",
          description: purpose,
          logo: "https://church-link.app/logo.png",
        ),
        isTestMode: PaymentConfig.isTestMode,
      );

      final ChargeResponse response = await flutterwave.charge(context);

      if (response.success ?? false) {
        final donationId = await logDonation(
          userId: user.id,
          amount: amount,
          currency: currency,
          paymentMethod: paymentMethod,
          purpose: purpose,
          donationType: donationType,
          message: message,
          transactionId: response.transactionId ?? txRef,
          status: 'completed',
          churchId: churchId,
          churchName: churchName,
        );

        // Send confirmation emails for card payments
        if (churchId != null) {
          final donation = {
            'id': donationId,
            'user_id': user.id,
            'church_id': churchId,
            'amount': amount,
            'church_name': churchName,
            'transaction_id': response.transactionId ?? txRef,
            'platform_fee': amount * 0.1,
            'church_amount': amount * 0.9,
          };
          await _sendDonationEmails(donation);
        }

        return {
          'status': 'success',
          'transaction_id': response.transactionId,
          'tx_ref': response.txRef,
          'donation_id': donationId,
        };
      } else {
        throw Exception(response.status ?? 'Card payment failed');
      }
    } catch (e) {
      print('Error processing card payment: $e');
      rethrow;
    }
  }
}
