import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user tier
  Future<String> getCurrentUserTier() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await _supabase.rpc('get_user_tier', params: {'p_user_id': user.id});
    return response as String? ?? 'basic';
  }

  // Upgrade user tier
  Future<void> upgradeTier(String newTier) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Validate tier
    if (!['basic', 'pro', 'kingdom'].contains(newTier)) {
      throw Exception('Invalid tier');
    }

    // Get pricing
    final pricing = {
      'pro': 20.0,
      'kingdom': 50.0,
    };

    if (newTier == 'basic') {
      // Downgrade to basic (free)
      await _supabase.rpc('update_user_tier', params: {
        'p_user_id': user.id,
        'p_new_tier': newTier,
        'p_reason': 'manual'
      });
      return;
    }

    final amount = pricing[newTier];
    if (amount == null) throw Exception('Invalid tier pricing');

    // Create subscription record
    final subscriptionEnd = DateTime.now().add(const Duration(days: 30));

    final subscription = await _supabase
        .from('subscriptions')
        .insert({
          'user_id': user.id,
          'tier': newTier,
          'amount': amount,
          'currency': 'ZMW',
          'payment_method': 'airtel', // Default to Airtel
          'subscription_start': DateTime.now().toIso8601String(),
          'subscription_end': subscriptionEnd.toIso8601String(),
          'next_payment_date': subscriptionEnd.toIso8601String(),
        })
        .select()
        .single();

    // Update user tier
    await _supabase.rpc('update_user_tier', params: {
      'p_user_id': user.id,
      'p_new_tier': newTier,
      'p_reason': 'upgrade'
    });

    // TODO: Trigger immediate payment for the subscription
    // For now, the monthly process-subscriptions function will handle it
  }

  // Get subscription details
  Future<Map<String, dynamic>?> getCurrentSubscription() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('subscriptions')
        .select('*')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  // Get subscription history
  Future<List<Map<String, dynamic>>> getSubscriptionHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('subscription_payments')
        .select('*, subscription:subscription_id(tier)')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Calculate fee for amount
  Future<double> calculateFee(double amount) async {
    final tier = await getCurrentUserTier();
    final response = await _supabase.rpc('calculate_admin_fee', params: {
      'p_amount': amount,
      'p_user_tier': tier
    });
    return (response as num?)?.toDouble() ?? (amount * 0.1);
  }
}