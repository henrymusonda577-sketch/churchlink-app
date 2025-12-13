import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/payment_config.dart';

class ChurchPayoutService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Flutterwave API endpoints
  static const String _baseUrl = 'https://api.flutterwave.com/v3';
  static const String _secretKey = PaymentConfig.flutterwaveSecretKey;

  // Create Flutterwave subaccount for church
  Future<Map<String, dynamic>?> createChurchSubaccount({
    required String churchId,
    required String accountName,
    required String accountNumber,
    required String bankCode,
    String? bankName,
    String? mobileProvider,
  }) async {
    try {
      final headers = {
        'Authorization': 'Bearer $_secretKey',
        'Content-Type': 'application/json',
      };

      // Prepare subaccount data based on account type
      Map<String, dynamic> subaccountData = {
        'account_name': accountName,
        'account_number': accountNumber,
        'business_name': accountName,
        'business_email': 'church@churchlink.app', // Generic email
        'country': 'ZM', // Zambia
        'split_type': 'percentage',
        'split_value': 90, // Church gets 90%
      };

      if (bankCode.isNotEmpty) {
        // Bank account
        subaccountData['account_bank'] = bankCode;
      } else if (mobileProvider != null) {
        // Mobile money account
        if (mobileProvider.toLowerCase() == 'airtel') {
          subaccountData['account_bank'] = 'AIRTELZM'; // Airtel Zambia code
        } else if (mobileProvider.toLowerCase() == 'mtn') {
          subaccountData['account_bank'] = 'MTNZM'; // MTN Zambia code
        }
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/subaccounts'),
        headers: headers,
        body: jsonEncode(subaccountData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final subaccount = data['data'];

          // Save to database
          await _supabase.from('church_payout_accounts').insert({
            'church_id': churchId,
            'account_type': bankCode.isNotEmpty ? 'bank' : 'mobile_money',
            'account_name': accountName,
            'account_number': accountNumber,
            'bank_name': bankName,
            'bank_code': bankCode,
            'mobile_provider': mobileProvider,
            'flutterwave_subaccount_id': subaccount['subaccount_id'],
            'flutterwave_account_id': subaccount['account_id'],
            'is_active': true,
          });

          return subaccount;
        }
      }

      print('Failed to create subaccount: ${response.body}');
      return null;
    } catch (e) {
      print('Error creating church subaccount: $e');
      return null;
    }
  }

  // Get church payout accounts
  Future<List<Map<String, dynamic>>> getChurchPayoutAccounts(String churchId) async {
    try {
      final response = await _supabase
          .from('church_payout_accounts')
          .select('*')
          .eq('church_id', churchId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting church payout accounts: $e');
      return [];
    }
  }

  // Update payout account status
  Future<bool> updatePayoutAccountStatus(String accountId, bool isActive) async {
    try {
      await _supabase
          .from('church_payout_accounts')
          .update({'is_active': isActive})
          .eq('id', accountId);

      return true;
    } catch (e) {
      print('Error updating payout account status: $e');
      return false;
    }
  }

  // Get active subaccount for church
  Future<Map<String, dynamic>?> getActiveChurchSubaccount(String churchId) async {
    try {
      final accounts = await getChurchPayoutAccounts(churchId);
      return accounts.isNotEmpty ? accounts.first : null;
    } catch (e) {
      print('Error getting active church subaccount: $e');
      return null;
    }
  }

  // Process donation split
  Future<bool> processDonationSplit({
    required String donationId,
    required double totalAmount,
    required String churchId,
  }) async {
    try {
      // Calculate splits: 10% platform, 90% church
      final platformFee = totalAmount * 0.1;
      final churchAmount = totalAmount * 0.9;

      // Get church subaccount
      final subaccount = await getActiveChurchSubaccount(churchId);
      if (subaccount == null) {
        print('No active subaccount found for church: $churchId');
        return false;
      }

      // Record splits in database
      await _supabase.from('donation_splits').insert([
        {
          'donation_id': donationId,
          'recipient_type': 'platform',
          'amount': platformFee,
          'currency': 'ZMW',
          'status': 'completed',
        },
        {
          'donation_id': donationId,
          'recipient_type': 'church',
          'recipient_id': churchId,
          'amount': churchAmount,
          'currency': 'ZMW',
          'status': 'pending', // Will be updated when payout is processed
          'flutterwave_split_id': subaccount['flutterwave_subaccount_id'],
        },
      ]);

      // Update donation record
      await _supabase.from('donations').update({
        'platform_fee': platformFee,
        'church_amount': churchAmount,
        'split_processed': true,
      }).eq('id', donationId);

      return true;
    } catch (e) {
      print('Error processing donation split: $e');
      return false;
    }
  }

  // Get donation splits for a donation
  Future<List<Map<String, dynamic>>> getDonationSplits(String donationId) async {
    try {
      final response = await _supabase
          .from('donation_splits')
          .select('*')
          .eq('donation_id', donationId)
          .order('created_at');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting donation splits: $e');
      return [];
    }
  }

  // Get subaccount balance from Flutterwave
  Future<double?> getSubaccountBalance(String subaccountId) async {
    try {
      final headers = {
        'Authorization': 'Bearer $_secretKey',
        'Content-Type': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$_baseUrl/subaccounts/$subaccountId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final subaccount = data['data'];
          // Flutterwave returns balance in the subaccount data
          return (subaccount['account_balance'] as num?)?.toDouble();
        }
      }

      print('Failed to get subaccount balance: ${response.body}');
      return null;
    } catch (e) {
      print('Error getting subaccount balance: $e');
      return null;
    }
  }

  // Initiate automatic payout from subaccount to church's payout account
  Future<Map<String, dynamic>?> initiatePayout({
    required String churchId,
    required double amount,
    String? narration,
  }) async {
    try {
      // Get active payout account
      final accounts = await getChurchPayoutAccounts(churchId);
      if (accounts.isEmpty) {
        throw Exception('No active payout account found for church');
      }

      final account = accounts.first;
      final subaccountId = account['flutterwave_subaccount_id'];

      if (subaccountId == null) {
        throw Exception('Subaccount not properly configured');
      }

      // Check balance
      final balance = await getSubaccountBalance(subaccountId);
      if (balance == null || balance < amount) {
        throw Exception('Insufficient funds in subaccount');
      }

      final headers = {
        'Authorization': 'Bearer $_secretKey',
        'Content-Type': 'application/json',
      };

      final payoutData = {
        'account_bank': account['bank_code'] ?? (account['mobile_provider'] == 'airtel' ? 'AIRTELZM' : 'MTNZM'),
        'account_number': account['account_number'],
        'amount': amount,
        'narration': narration ?? 'Church payout from Church Link',
        'currency': 'ZMW',
        'reference': 'PAYOUT_${DateTime.now().millisecondsSinceEpoch}',
        'debit_subaccount': subaccountId,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/transfers'),
        headers: headers,
        body: jsonEncode(payoutData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final transfer = data['data'];

          // Record payout in database
          await _supabase.from('payout_history').insert({
            'church_id': churchId,
            'payout_account_id': account['id'],
            'amount': amount,
            'currency': 'ZMW',
            'flutterwave_transfer_id': transfer['id'],
            'reference': transfer['reference'],
            'status': 'pending',
            'narration': narration,
            'method': 'automatic',
          });

          return transfer;
        }
      }

      print('Failed to initiate payout: ${response.body}');
      return null;
    } catch (e) {
      print('Error initiating payout: $e');
      rethrow;
    }
  }

  // Initiate manual payout request
  Future<Map<String, dynamic>?> initiateManualPayout({
    required String churchId,
    required double amount,
    String? narration,
  }) async {
    try {
      // Get active payout account
      final accounts = await getChurchPayoutAccounts(churchId);
      if (accounts.isEmpty) {
        throw Exception('No active payout account found for church');
      }

      final account = accounts.first;

      // Check available balance from view
      final balance = await getChurchBalance(churchId);
      if (balance == null || balance['available_balance'] < amount) {
        throw Exception('Insufficient available balance');
      }

      // Record manual payout request
      final response = await _supabase.from('payout_history').insert({
        'church_id': churchId,
        'payout_account_id': account['id'],
        'amount': amount,
        'currency': 'ZMW',
        'reference': 'MANUAL_PAYOUT_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'pending',
        'narration': narration ?? 'Manual church payout',
        'method': 'manual',
      }).select('id').single();

      return {
        'id': response['id'],
        'reference': 'MANUAL_PAYOUT_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'pending',
      };
    } catch (e) {
      print('Error initiating manual payout: $e');
      rethrow;
    }
  }

  // Mark manual payout as completed (admin function)
  Future<bool> markPayoutCompleted(String payoutId, String adminId) async {
    try {
      await _supabase.from('payout_history').update({
        'status': 'successful',
        'processed_at': DateTime.now().toIso8601String(),
        'admin_id': adminId,
      }).eq('id', payoutId).eq('method', 'manual');

      return true;
    } catch (e) {
      print('Error marking payout completed: $e');
      return false;
    }
  }

  // Get payout history for church
  Future<List<Map<String, dynamic>>> getChurchPayoutHistory(String churchId) async {
    try {
      final response = await _supabase
          .from('payout_history')
          .select('*')
          .eq('church_id', churchId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting payout history: $e');
      return [];
    }
  }

  // Update payout status (called by webhook or manual check)
  Future<bool> updatePayoutStatus(String transferId, String status) async {
    try {
      await _supabase
          .from('payout_history')
          .update({
            'status': status,
            'processed_at': status == 'successful' ? DateTime.now().toIso8601String() : null,
          })
          .eq('flutterwave_transfer_id', transferId);

      return true;
    } catch (e) {
      print('Error updating payout status: $e');
      return false;
    }
  }

  // Get church balance from view
  Future<Map<String, dynamic>?> getChurchBalance(String churchId) async {
    try {
      final response = await _supabase
          .from('church_balances')
          .select('*')
          .eq('church_id', churchId)
          .single();

      return response;
    } catch (e) {
      print('Error getting church balance: $e');
      return null;
    }
  }

  // Get church donation summary
  Future<Map<String, dynamic>> getChurchDonationSummary(String churchId) async {
    try {
      final response = await _supabase
          .from('donations')
          .select('amount, platform_fee, church_amount, status, created_at')
          .eq('church_id', churchId)
          .eq('status', 'completed');

      final donations = List<Map<String, dynamic>>.from(response);

      double totalReceived = 0;
      double totalPlatformFees = 0;
      double totalChurchAmount = 0;
      int donationCount = donations.length;

      for (final donation in donations) {
        totalReceived += (donation['amount'] as num?)?.toDouble() ?? 0;
        totalPlatformFees += (donation['platform_fee'] as num?)?.toDouble() ?? 0;
        totalChurchAmount += (donation['church_amount'] as num?)?.toDouble() ?? 0;
      }

      // Get payout history
      final payoutHistory = await getChurchPayoutHistory(churchId);
      double totalPaidOut = 0;
      for (final payout in payoutHistory) {
        if (payout['status'] == 'successful') {
          totalPaidOut += (payout['amount'] as num?)?.toDouble() ?? 0;
        }
      }

      // Get available balance (church amount minus paid out)
      final availableBalance = totalChurchAmount - totalPaidOut;

      return {
        'total_received': totalReceived,
        'total_platform_fees': totalPlatformFees,
        'total_church_amount': totalChurchAmount,
        'total_paid_out': totalPaidOut,
        'available_balance': availableBalance,
        'donation_count': donationCount,
        'donations': donations,
        'payout_history': payoutHistory,
      };
    } catch (e) {
      print('Error getting church donation summary: $e');
      return {
        'total_received': 0.0,
        'total_platform_fees': 0.0,
        'total_church_amount': 0.0,
        'total_paid_out': 0.0,
        'available_balance': 0.0,
        'donation_count': 0,
        'donations': [],
        'payout_history': [],
      };
    }
  }
}