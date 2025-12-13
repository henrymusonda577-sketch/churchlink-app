import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Fetch all users from the 'users' table
  static Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      final response = await _client
          .from('users')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  // Insert new user into the 'users' table
  static Future<bool> insertUser({
    required String name,
    required String email,
    String? phone,
  }) async {
    try {
      await _client.from('users').insert({
        'name': name,
        'email': email,
        'phone': phone,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error inserting user: $e');
      return false;
    }
  }

  // Subscribe to real-time updates on 'users' table
  static Stream<List<Map<String, dynamic>>> subscribeToUsers() {
    return _client
        .from('users')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  // Update user by ID
  static Future<bool> updateUser(int id, Map<String, dynamic> updates) async {
    try {
      await _client.from('users').update(updates).eq('id', id);
      return true;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  // Delete user by ID
  static Future<bool> deleteUser(int id) async {
    try {
      await _client.from('users').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Error deleting user from users table: $e');
      // Note: This deletes from the custom 'users' table, not auth.users
      // For complete user deletion, use deleteUserCompletely() method
      return false;
    }
  }

  // Delete user completely using Supabase Admin API (requires server-side implementation)
  static Future<bool> deleteUserCompletely(String userId) async {
    try {
      // This would need to be implemented as a server-side function
      // since service role key should not be exposed client-side
      final response = await _client.functions.invoke('delete-user', body: {
        'userId': userId,
      });

      if (response.status == 200) {
        return true;
      } else {
        print('Error deleting user completely: ${response.data}');
        return false;
      }
    } catch (e) {
      print('Error calling delete-user function: $e');
      return false;
    }
  }

  // Delete all users completely (DANGER: This will delete ALL users and their data)
  static Future<Map<String, dynamic>> deleteAllUsersCompletely() async {
    try {
      final response = await _client.functions.invoke('delete-all-users', body: {});

      if (response.status == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'All users deleted successfully',
          'deletedCount': response.data['deletedCount'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to delete users',
          'error': response.data,
        };
      }
    } catch (e) {
      print('Error calling delete-all-users function: $e');
      return {
        'success': false,
        'message': 'Error calling delete function: $e',
        'error': e.toString(),
      };
    }
  }
}