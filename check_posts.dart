import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final supabase = Supabase.instance.client;

  final response = await supabase.from('posts').select('id');
  print('Number of posts: ${response.length}');
  if (response.isNotEmpty) {
    print('Post IDs: ${response.map((p) => p['id']).toList()}');
  }
}