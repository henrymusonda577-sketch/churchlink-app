import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // Load environment variables
  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    print('Error: Supabase credentials not found in .env file');
    return;
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final supabase = Supabase.instance.client;

  try {
    print('Fetching all posts...');
    final response = await supabase.from('posts').select('id, content, post_type, user_id');

    print('Found ${response.length} posts');
    for (var post in response) {
      print('Post ID: ${post['id']}, Type: ${post['post_type']}, User: ${post['user_id']}, Content: ${post['content']}');
    }

    if (response.isEmpty) {
      print('No posts found to delete');
      return;
    }

    print('\nDeleting all posts...');
    final deleteResponse = await supabase.from('posts').delete().neq('id', '00000000-0000-0000-0000-000000000000'); // Delete all

    print('Delete operation completed');
    print('All posts deleted successfully');

  } catch (e) {
    print('Error: $e');
  }
}