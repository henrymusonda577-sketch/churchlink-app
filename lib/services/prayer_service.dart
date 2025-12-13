import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PrayerService extends ChangeNotifier {
  static final PrayerService _instance = PrayerService._internal();
  factory PrayerService() => _instance;
  PrayerService._internal();

  Future<void> addPrayer(Map<String, dynamic> prayerData) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await Supabase.instance.client.from('prayers').insert({
        'title': prayerData['title'],
        'content': prayerData['prayer'],
        'is_public': prayerData['isPublic'],
        'author_id': user.id,
        'author_name': prayerData['author'],
        'author_role': prayerData['authorRole'],
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to add prayer: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPublicPrayers() async {
    try {
      final response = await Supabase.instance.client
          .from('prayers')
          .select()
          .eq('is_public', true)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserPrayers() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final response = await Supabase.instance.client
          .from('prayers')
          .select()
          .eq('author_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
}
