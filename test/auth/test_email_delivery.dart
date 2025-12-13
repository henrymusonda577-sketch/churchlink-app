import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient supabase;

  setUpAll(() async {
    // Initialize Supabase client
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
    supabase = Supabase.instance.client;
  });

  group('Email Delivery Tests', () {
    test('Should send verification email', () async {
      final testEmail = 'test@yourdomain.com'; // Replace with your test email

      try {
        final res = await supabase.auth.signInWithOtp(
          email: testEmail,
        );

        // If no exception is thrown, the request was accepted
        expect(res.session, isNull);
        print('✓ Verification email request accepted by Supabase');
        print('➜ Check your email inbox and Supabase Auth logs');
        
      } catch (e) {
        fail('Failed to send verification email: $e');
      }
    });

    // Add a delay to allow time to check email
    test('Wait for manual email verification', () async {
      await Future.delayed(const Duration(minutes: 2));
      print('Please verify that the test email was received');
    });
  });
}