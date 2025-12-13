import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Validate current session and refresh if needed
  Future<bool> _validateSession() async {
    try {
      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;

      if (session == null || user == null) {
        print('No valid session or user found');
        return false;
      }

      // Check if session is expired
      final now = DateTime.now().toUtc();
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final expiryDate =
            DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
        if (now.isAfter(expiryDate)) {
          print('Session expired, attempting refresh...');
          try {
            await _supabase.auth.refreshSession();
            print('Session refreshed successfully');
            return true;
          } catch (e) {
            print('Failed to refresh session: $e');
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      print('Error validating session: $e');
      return false;
    }
  }

  // Get current user info
  Future<Map<String, dynamic>?> getUserInfo() async {
    if (!await _validateSession()) {
      print('DEBUG UserService.getUserInfo: Session validation failed');
      return null;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('DEBUG UserService.getUserInfo: No current user');
        return null;
      }

      print('DEBUG UserService.getUserInfo: Getting user info for user ID: ${user.id}');
      print('DEBUG UserService.getUserInfo: User metadata: ${user.userMetadata}');

      print('DEBUG UserService.getUserInfo: Querying users table for user ID: ${user.id}');
      try {
        final response =
            await _supabase.from('users').select().eq('id', user.id).single();

        print('DEBUG UserService.getUserInfo: Query response: $response');
        print(
            'DEBUG UserService.getUserInfo: User data retrieved successfully: ${response['name'] ?? 'Unknown'}, role: ${response['role']}, church_id: ${response['church_id']}, church_name: ${response['church_name']}');
        
        // Additional check for church membership if church_id is missing
        if ((response['church_id'] == null || response['church_id'].toString().isEmpty) && response['role'] != 'pastor') {
          print('DEBUG UserService.getUserInfo: User has no church_id, checking church_members table...');
          try {
            final membershipResponse = await _supabase
                .from('church_members')
                .select('church_id, churches!inner(id, church_name)')
                .eq('user_id', user.id)
                .limit(1);
            
            if (membershipResponse.isNotEmpty) {
              final membership = membershipResponse.first;
              final churchData = membership['churches'];
              print('DEBUG UserService.getUserInfo: Found church membership: ${churchData['church_name']}');
              
              // Update user record with church info
              await _supabase.from('users').update({
                'church_id': churchData['id'],
                'church_name': churchData['church_name'],
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', user.id);
              
              // Update response
              response['church_id'] = churchData['id'];
              response['church_name'] = churchData['church_name'];
              print('DEBUG UserService.getUserInfo: Updated user record with church info');
            }
          } catch (membershipError) {
            print('DEBUG UserService.getUserInfo: Error checking church membership: $membershipError');
          }
        }
        
        return response;
      } catch (idError) {
        print('DEBUG UserService.getUserInfo: Query by ID failed: $idError');
        // Try querying by email instead
        if (user.email != null) {
          print('DEBUG UserService.getUserInfo: Trying query by email: ${user.email}');
          final emailResponse =
              await _supabase.from('users').select().eq('email', user.email!).single();
          print('DEBUG UserService.getUserInfo: Query by email response: $emailResponse');
          print(
              'DEBUG UserService.getUserInfo: User data retrieved by email: ${emailResponse['name'] ?? 'Unknown'}, role: ${emailResponse['role']}, church_id: ${emailResponse['church_id']}');
  
          // Check if user has church_id, if not, try to find and set it
          if (emailResponse['church_id'] == null) {
            print('DEBUG UserService.getUserInfo: User has no church_id, checking for church');
            try {
              final churches = await _supabase
                  .from('churches')
                  .select()
                  .eq('pastor_id', emailResponse['id']);
              if (churches.isNotEmpty) {
                final churchData = churches.first;
                print('DEBUG UserService.getUserInfo: Found church for user, updating user data with church_id');
                await _supabase.from('users').update({
                  'church_id': churchData['id'],
                  'church_name': churchData['church_name'],
                  'position_in_church': 'pastor',
                  'role': 'pastor',
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', emailResponse['id']);
                // Update the response
                emailResponse['church_id'] = churchData['id'];
                emailResponse['church_name'] = churchData['church_name'];
                emailResponse['position_in_church'] = 'pastor';
                emailResponse['role'] = 'pastor';
                print('DEBUG UserService.getUserInfo: Updated user data with church info');
              }
            } catch (churchError) {
              print('DEBUG UserService.getUserInfo: Error checking/updating church for user: $churchError');
            }
          }
  
          return emailResponse;
        } else {
          print('DEBUG UserService.getUserInfo: No email available for fallback query');
        }
      }
    } catch (e) {
      print('DEBUG UserService.getUserInfo: Error getting user info: $e');
      // If user data doesn't exist, check if user has a church (is pastor)
      final user = _supabase.auth.currentUser;
      if (user != null) {
        print('DEBUG UserService.getUserInfo: Checking if user has a church since not in users table');
        try {
          final churches = await _supabase
              .from('churches')
              .select()
              .eq('pastor_id', user.id);
          if (churches.isNotEmpty) {
            final churchData = churches.first;
            print('DEBUG UserService.getUserInfo: Found church for user: ${churchData['church_name']}, trying to upsert user data');
            try {
              // Try to upsert user data directly
              final userData = {
                'id': user.id,
                'email': user.email ?? '',
                'name': user.userMetadata?['name'] ?? user.userMetadata?['first_name'] ?? user.email?.split('@')[0] ?? 'User',
                'role': 'pastor',
                'position_in_church': 'pastor',
                'church_name': churchData['church_name'],
                'church_id': churchData['id'],
                'phone': user.phone ?? '',
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              };
              print('DEBUG UserService.getUserInfo: Upserting user data: $userData');
              await _supabase.from('users').upsert(userData, onConflict: 'id');
              print('DEBUG UserService.getUserInfo: Successfully upserted user data');
            } catch (upsertError) {
              print('DEBUG UserService.getUserInfo: Error upserting user data: $upsertError');
              // Try to update by email if upsert fails
              if (user.email != null) {
                try {
                  print('DEBUG UserService.getUserInfo: Trying to update by email');
                  await _supabase.from('users').update({
                    'id': user.id,
                    'role': 'pastor',
                    'position_in_church': 'pastor',
                    'church_name': churchData['church_name'],
                    'church_id': churchData['id'],
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('email', user.email!);
                  print('DEBUG UserService.getUserInfo: Successfully updated user data by email');
                } catch (updateError) {
                  print('DEBUG UserService.getUserInfo: Error updating user data by email: $updateError');
                }
              }
            }
            // Get the saved/updated data
            final savedData = await getUserInfo();
            if (savedData != null) {
              print('DEBUG UserService.getUserInfo: Successfully retrieved user data after upsert/update');
              return savedData;
            }
          }
        } catch (churchError) {
          print('DEBUG UserService.getUserInfo: Error checking for user church: $churchError');
        }

        // Fallback to basic user info from auth
        print('DEBUG UserService.getUserInfo: Returning basic user info from auth since user data not found in database');

        // Check user metadata for position_in_church to determine role
        final userMetadata = user.userMetadata ?? {};
        final positionInChurch = userMetadata['position_in_church'] ?? '';
        final position = positionInChurch.toLowerCase();
        String role = 'Member';
        if (position.contains('pastor') || position.contains('elder') ||
            position.contains('bishop') || position.contains('apostle') ||
            position.contains('reverend') || position.contains('minister') ||
            position.contains('evangelist') || position.contains('administrator') ||
            position.contains('council')) {
          role = 'pastor';
        }

        print('DEBUG UserService.getUserInfo: Determined role from metadata: $role, position: $positionInChurch');

        return {
          'id': user.id,
          'email': user.email,
          'name': 'User',
          'role': role,
          'phone': user.phone,
        };
      }
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> userData) async {
    if (!await _validateSession()) {
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      userData['updated_at'] = DateTime.now().toIso8601String();

      print('DEBUG UserService.updateUserProfile: Updating user profile with data: $userData');

      await _supabase.from('users').update(userData).eq('id', user.id);

      print('DEBUG UserService.updateUserProfile: User profile updated successfully');
    } catch (e) {
      print('Error updating user profile: $e');
      throw e;
    }
  }

  // Upload profile picture
  Future<Map<String, dynamic>> uploadProfilePicture(dynamic imageFile) async {
    if (!await _validateSession()) {
      return {
        'success': false,
        'error': 'User not authenticated',
        'url': null,
      };
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
          'url': null,
        };
      }

      Uint8List imageBytes;
      if (imageFile is File) {
        imageBytes = await imageFile.readAsBytes();
      } else if (imageFile is Uint8List) {
        imageBytes = imageFile;
      } else {
        return {
          'success': false,
          'error': 'Unsupported image type',
          'url': null,
        };
      }

      final fileName =
          'profile_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage
          .from('church-profile-pictures')
          .uploadBinary(fileName, imageBytes);

      final url =
          _supabase.storage.from('church-profile-pictures').getPublicUrl(fileName);

      print('DEBUG UserService.uploadProfilePicture: Generated URL: $url');

      // Update user profile with new picture URL
      print('DEBUG UserService.uploadProfilePicture: Updating user profile with new picture URL');
      await updateUserProfile({'profile_picture_url': url});

      print('DEBUG UserService.uploadProfilePicture: Profile picture upload completed successfully');

      return {
        'success': true,
        'error': null,
        'url': url,
      };
    } catch (e) {
      print('Error uploading profile picture: $e');
      return {
        'success': false,
        'error': e.toString(),
        'url': null,
      };
    }
  }

  // Get profile picture URL
  Future<String?> getProfilePictureUrl(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('profile_picture_url')
          .eq('id', userId)
          .single();

      return response['profile_picture_url'];
    } catch (e) {
      print('Error getting profile picture URL: $e');
      return null;
    }
  }

  // Follow a user
  Future<void> followUser(String targetUserId) async {
    if (!await _validateSession()) {
      return;
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      // Get current user's name for the notification title
      final currentUserData = await getUserInfo();
      final currentUserName = currentUserData?['name'] ?? 'Someone';

      // Insert follow relationship
      await _supabase.from('follows').insert({
        'follower_id': currentUser.id,
        'following_id': targetUserId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create follow notification
      await _supabase.from('notifications').insert({
        'user_id': targetUserId,
        'type': 'follow',
        'from_user_id': currentUser.id,
        'message': '$currentUserName started following you',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error following user: $e');
      throw e;
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String targetUserId) async {
    if (!await _validateSession()) {
      return;
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      await _supabase
          .from('follows')
          .delete()
          .eq('follower_id', currentUser.id)
          .eq('following_id', targetUserId);
    } catch (e) {
      print('Error unfollowing user: $e');
      throw e;
    }
  }

  // Check if current user is following another user
  Future<bool> isFollowing(String targetUserId) async {
    if (!await _validateSession()) {
      return false;
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      final response = await _supabase
          .from('follows')
          .select()
          .eq('follower_id', currentUser.id)
          .eq('following_id', targetUserId);

      return response.isNotEmpty;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  // Accept follow request
  Future<void> acceptFollowRequest(String fromUserId) async {
    if (!await _validateSession()) {
      return;
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      // Get current user's name for the notification title
      final currentUserData = await getUserInfo();
      final currentUserName = currentUserData?['name'] ?? 'Someone';

      // Create acceptance notification
      await _supabase.from('notifications').insert({
        'user_id': fromUserId,
        'type': 'follow_accepted',
        'from_user_id': currentUser.id,
        'message': '$currentUserName accepted your follow request',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Mark original notification as read
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', currentUser.id)
          .eq('from_user_id', fromUserId)
          .eq('type', 'follow_request');
    } catch (e) {
      print('Error accepting follow request: $e');
      throw e;
    }
  }

  // Reject follow request
  Future<void> rejectFollowRequest(String fromUserId) async {
    if (!await _validateSession()) {
      return;
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      // Mark notification as read
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', currentUser.id)
          .eq('from_user_id', fromUserId)
          .eq('type', 'follow_request');

      // Delete the follow relationship
      await _supabase
          .from('follows')
          .delete()
          .eq('follower_id', fromUserId)
          .eq('following_id', currentUser.id);
    } catch (e) {
      print('Error rejecting follow request: $e');
      throw e;
    }
  }

  // Get users to discover
  Future<List<Map<String, dynamic>>> getDiscoverableUsers() async {
    if (!await _validateSession()) {
      return [];
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

      // Get users that current user is not following
      final response = await _supabase
          .from('users')
          .select()
          .neq('id', currentUser.id)
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting discoverable users: $e');
      return [];
    }
  }

  // Get user's followers
  Future<List<Map<String, dynamic>>> getUserFollowers(String userId) async {
    try {
      final response = await _supabase
          .from('follows')
          .select('follower_id, users!follows_follower_id_fkey(*)')
          .eq('following_id', userId);

      return response.map<Map<String, dynamic>>((follow) {
        final userData = follow['users'] as Map<String, dynamic>;
        userData['uid'] = userData['id'];
        return userData;
      }).toList();
    } catch (e) {
      print('Error getting user followers: $e');
      return [];
    }
  }

  // Get user's following
  Future<List<Map<String, dynamic>>> getUserFollowing(String userId) async {
    try {
      // First get the following IDs
      final followsResponse = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      final followingIds = followsResponse.map((f) => f['following_id'] as String).toList();

      if (followingIds.isEmpty) {
        return [];
      }

      // Then get the user data for those IDs
      final usersResponse = await _supabase
          .from('users')
          .select()
          .filter('id', 'in', '(${followingIds.map((id) => '"$id"').join(',')})');

      return usersResponse.map<Map<String, dynamic>>((user) {
        user['uid'] = user['id'];
        return user;
      }).toList();
    } catch (e) {
      print('Error getting user following: $e');
      return [];
    }
  }

  // Get user by ID
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final response =
          await _supabase.from('users').select().eq('id', userId).single();

      response['uid'] = response['id'];
      return response;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  // Search users
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (!await _validateSession()) {
      return [];
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

      final response = await _supabase
          .from('users')
          .select()
          .ilike('name', '%$query%')
          .neq('id', currentUser.id)
          .limit(10);

      return response.map<Map<String, dynamic>>((user) {
        user['uid'] = user['id'];
        return user;
      }).toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Get follow requests stream
  Stream<List<Map<String, dynamic>>> getFollowRequests() {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data
            .where((notification) =>
                notification['user_id'] == currentUser.id &&
                notification['type'] == 'follow_request' &&
                notification['is_read'] == false)
            .toList());
  }

  // Get notifications stream
  Stream<List<Map<String, dynamic>>> getNotifications() {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUser.id)
        .order('created_at', ascending: false)
        .limit(50);
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    if (!await _validateSession()) {
      return;
    }

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
      throw e;
    }
  }

  // Get user stats
  Future<Map<String, int>> getUserStats(String userId) async {
    try {
      // Get followers count
      final followersResponse = await _supabase
          .from('follows')
          .select('id')
          .eq('following_id', userId);

      // Get following count
      final followingResponse = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', userId);

      // Get posts count
      final postsResponse =
          await _supabase.from('posts').select('id').eq('user_id', userId);

      return {
        'posts': postsResponse.length,
        'followers': followersResponse.length,
        'following': followingResponse.length,
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return {'posts': 0, 'followers': 0, 'following': 0};
    }
  }

  // Save user info
  Future<void> saveUserInfo({
    required String name,
    required String role,
    required String email,
    String? profilePictureUrl,
    String? bio,
    String? relationshipStatus,
    String? positionInChurch,
    String? churchName,
    String? birthday,
    String? gender,
    String? referrerId,
  }) async {
    if (!await _validateSession()) {
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final userData = {
        'id': user.id,
        'email': email,
        'name': name,
        'phone': '',
        'role': role,
        'profile_picture_url': profilePictureUrl,
        'bio': bio ?? '',
        'relationship_status': relationshipStatus ?? '',
        'position_in_church': positionInChurch ?? '',
        'church_name': churchName ?? '',
        'birthday': birthday,
        'gender': gender,
        'last_login': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Only add referrer_id if it's not null (to avoid column not found error)
      if (referrerId != null) {
        userData['referrer_id'] = referrerId;
      }

      await _supabase.from('users').upsert(userData);
    } catch (e) {
      print('Error saving user info: $e');
      rethrow;
    }
  }

  // Update profile picture by URL
  Future<void> updateProfilePicture(String profilePictureUrl) async {
    if (!await _validateSession()) {
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('users')
          .update({'profile_picture_url': profilePictureUrl}).eq('id', user.id);
    } catch (e) {
      print('Error updating profile picture URL: $e');
      rethrow;
    }
  }

  // Get church members
  Future<List<Map<String, dynamic>>> getChurchMembers() async {
    if (!await _validateSession()) {
      return [];
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

      // Get current user's church information
      final currentUserData = await getUserInfo();
      if (currentUserData == null) return [];

      final churchName = currentUserData['church_name'];
      if (churchName == null || churchName.isEmpty) return [];

      // Get all users with the same church name
      final response =
          await _supabase.from('users').select().eq('church_name', churchName);

      return response.map<Map<String, dynamic>>((user) {
        user['userId'] = user['id'];
        return user;
      }).toList();
    } catch (e) {
      print('Error getting church members: $e');
      return [];
    }
  }

  // Set user online status
  Future<void> setUserOnline() async {
    if (!await _validateSession()) {
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('users').update({
        'is_online': true,
        'last_active': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      print('Error setting user online: $e');
      throw e;
    }
  }

  // Set user offline status
  Future<void> setUserOffline() async {
    if (!await _validateSession()) {
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('users').update({
        'is_online': false,
        'last_active': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      print('Error setting user offline: $e');
      throw e;
    }
  }

  // Get user presence status
  Future<Map<String, dynamic>?> getUserPresence(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('is_online, last_active')
          .eq('id', userId)
          .single();

      return {
        'isOnline': response['is_online'] ?? false,
        'lastActive': response['last_active'],
      };
    } catch (e) {
      print('Error getting user presence: $e');
      return null;
    }
  }

  // Stream user presence for real-time updates
  Stream<Map<String, dynamic>?> getUserPresenceStream(String userId) {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) {
          if (data.isNotEmpty) {
            final user = data.first;
            return {
              'isOnline': user['is_online'] ?? false,
              'lastActive': user['last_active'],
            };
          }
          return null;
        });
  }

  // Get mutual followers
  Future<List<Map<String, dynamic>>> getMutualFollowers() async {
    if (!await _validateSession()) {
      return [];
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

      // Get users I follow
      final following = await getUserFollowing(currentUser.id);
      final followingIds =
          following.map((user) => user['uid'] as String).toSet();

      // Get users who follow me
      final followers = await getUserFollowers(currentUser.id);
      final followerIds =
          followers.map((user) => user['uid'] as String).toSet();

      // Find intersection (mutual follows)
      final mutualIds = followingIds.intersection(followerIds);

      // Get full user data for mutual follows
      final mutualUsers = <Map<String, dynamic>>[];
      for (final userId in mutualIds) {
        final user = following.firstWhere((u) => u['uid'] == userId);
        mutualUsers.add(user);
      }

      return mutualUsers;
    } catch (e) {
      print('Error getting mutual followers: $e');
      return [];
    }
  }

  // Check if current user is a pastor
  Future<bool> isUserPastor() async {
    if (!await _validateSession()) {
      return false;
    }

    try {
      final userInfo = await getUserInfo();
      if (userInfo != null) {
        return userInfo['role'] == 'pastor';
      }
      return false;
    } catch (e) {
      print('Error checking if user is pastor: $e');
      return false;
    }
  }

  // Check if current user is an admin
  Future<bool> isUserAdmin() async {
    if (!await _validateSession()) {
      return false;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // For now, check if email is in admin list (you can modify this)
      final adminEmails = ['henrymusonda577@gmail.com', 'admin@churchlink.app', 'owner@churchlink.app']; // Add your admin emails
      return adminEmails.contains(user.email);
    } catch (e) {
      print('Error checking if user is admin: $e');
      return false;
    }
  }
}
