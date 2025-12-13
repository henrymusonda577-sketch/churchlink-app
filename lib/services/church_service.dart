import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'notification_service.dart';

class ChurchService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Create a new church (for pastors)
  Future<void> createChurch({
    required String churchName,
    required String description,
    required String address,
    required String phone,
    required String email,
    required String website,
    required String denomination,
    required String pastorName,
    required String pastorPhone,
    required String pastorEmail,
    String? churchImageUrl,
    String? churchLogoUrl,
    List<String>? services,
    List<String>? ministries,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    // Check if pastor already has a church
    final existingChurches = await _supabase
        .from('churches')
        .select('id')
        .eq('pastor_id', currentUser.id);
    if (existingChurches.isNotEmpty) {
      throw Exception('You can only create one church per pastor account.');
    }

    try {
      final insertData = {
        'name': churchName,
        'church_name': churchName,
        'description': description,
        'address': address,
        'location': address,
        'phone': phone,
        'email': email,
        'website': website,
        'denomination': denomination,
        'pastor_name': pastorName,
        'pastor_phone': pastorPhone,
        'pastor_email': pastorEmail,
        'pastor_id': currentUser.id,
        'church_image_url': churchImageUrl,
        'church_logo_url': churchLogoUrl,
        'services': services ?? [],
        'ministries': ministries ?? [],
        'member_count': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      print('DEBUG ChurchService: Inserting church data: $insertData');
      final response = await _supabase
          .from('churches')
          .insert(insertData)
          .select()
          .single();

      final churchId = response['id'];

      // Add pastor as first member
      await _supabase.from('church_members').insert({
        'church_id': churchId,
        'user_id': currentUser.id,
        'role': 'pastor',
        'joined_at': DateTime.now().toIso8601String(),
      });

      // Update user's church membership
      try {
        await _supabase.from('users').upsert({
          'id': currentUser.id,
          'church_id': churchId,
          'position_in_church': 'pastor',
          'church_name': churchName,
          'name': currentUser.userMetadata?['name'] ?? 'User',
          'email': currentUser.email,
          'role': 'pastor',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');
        print('DEBUG ChurchService.createChurch: Successfully upserted user data');
      } catch (upsertError) {
        print('DEBUG ChurchService.createChurch: Error upserting user data: $upsertError');
        // Try to update by email if upsert fails
        if (currentUser.email != null) {
          try {
            await _supabase.from('users').update({
              'id': currentUser.id,
              'church_id': churchId,
              'position_in_church': 'pastor',
              'church_name': churchName,
              'role': 'pastor',
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('email', currentUser.email!);
            print('DEBUG ChurchService.createChurch: Successfully updated user data by email');
          } catch (updateError) {
            print('DEBUG ChurchService.createChurch: Error updating user data by email: $updateError');
          }
        }
      }
    } catch (e) {
      print('Error creating church: $e');
      rethrow;
    }
  }

  // Get churches for discovery
  Stream<List<Map<String, dynamic>>> getChurches() {
    return _supabase
        .from('churches')
        .stream(primaryKey: ['id']).order('church_name');
  }

  // Search churches by name or denomination
  Future<List<Map<String, dynamic>>> searchChurches(String searchQuery) async {
    try {
      if (searchQuery.isEmpty) {
        final response = await _supabase
            .from('churches')
            .select()
            .order('church_name')
            .limit(20);
        return List<Map<String, dynamic>>.from(response);
      }

      final response = await _supabase
          .from('churches')
          .select()
          .or('church_name.ilike.%$searchQuery%,denomination.ilike.%$searchQuery%')
          .order('church_name')
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error searching churches: $e');
      return [];
    }
  }

  // Get church by ID
  Future<Map<String, dynamic>?> getChurchById(String churchId) async {
    try {
      final response =
          await _supabase.from('churches').select().eq('id', churchId).single();

      return response;
    } catch (e) {
      print('Error getting church by ID: $e');
      return null;
    }
  }

  // Get church by pastor ID
  Future<Map<String, dynamic>?> getChurchByPastorId(String pastorId) async {
    try {
      final response = await _supabase
          .from('churches')
          .select()
          .eq('pastor_id', pastorId)
          .single();

      return response;
    } catch (e) {
      print('Error getting church by pastor ID: $e');
      return null;
    }
  }

  // Join church as member
  Future<void> joinChurch(String churchId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    print('DEBUG ChurchService.joinChurch: Starting join process for churchId: $churchId, userId: ${currentUser.id}');

    try {
      // Check if already a member
      final existingMember = await _supabase
          .from('church_members')
          .select()
          .eq('church_id', churchId)
          .eq('user_id', currentUser.id);

      print('DEBUG ChurchService.joinChurch: existingMember check result: ${existingMember.length}');

      if (existingMember.isNotEmpty) {
        print('DEBUG ChurchService.joinChurch: User is already a member, returning');
        return;
      }

      // Get church data
      final churchData = await getChurchById(churchId);
      if (churchData == null) {
        print('DEBUG ChurchService.joinChurch: Church data is null, returning');
        return;
      }

      print('DEBUG ChurchService.joinChurch: Church data retrieved: member_count = ${churchData['member_count']}');

      // Add as member
      print('DEBUG ChurchService.joinChurch: Inserting into church_members');
      await _supabase.from('church_members').insert({
        'church_id': churchId,
        'user_id': currentUser.id,
        'role': 'member',
        'joined_at': DateTime.now().toIso8601String(),
      });
      print('DEBUG ChurchService.joinChurch: Successfully inserted into church_members');

      // Update member count manually
      print('DEBUG ChurchService.joinChurch: Updating member count manually');
      final newCount = (churchData['member_count'] ?? 0) + 1;
      await _supabase.from('churches').update({
        'member_count': newCount,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', churchId);
      print('DEBUG ChurchService.joinChurch: Manual increment successful, new count: $newCount');

      // Update user's church membership
      print('DEBUG ChurchService.joinChurch: Updating user data');
      await _supabase.from('users').update({
        'church_id': churchId,
        'position_in_church': 'member',
        'church_name': churchData['church_name'],
      }).eq('id', currentUser.id);

      // Remove from visitors if they were a visitor
      print('DEBUG ChurchService.joinChurch: Removing from visitors');
      await _supabase
          .from('church_visitors')
          .delete()
          .eq('church_id', churchId)
          .eq('user_id', currentUser.id);

      print('DEBUG ChurchService.joinChurch: Join process completed successfully');
    } catch (e) {
      print('Error joining church: $e');
      rethrow;
    }
  }

  // Register as visitor
  Future<void> registerAsVisitor(String churchId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Check if already a visitor or member
      final existingVisitor = await _supabase
          .from('church_visitors')
          .select()
          .eq('church_id', churchId)
          .eq('user_id', currentUser.id);

      final existingMember = await _supabase
          .from('church_members')
          .select()
          .eq('church_id', churchId)
          .eq('user_id', currentUser.id);

      if (existingVisitor.isNotEmpty || existingMember.isNotEmpty) return;

      // Get church data
      final churchData = await getChurchById(churchId);
      if (churchData == null) return;

      // Add as visitor
      await _supabase.from('church_visitors').insert({
        'church_id': churchId,
        'user_id': currentUser.id,
        'visited_at': DateTime.now().toIso8601String(),
      });

      // Update user's church status
      await _supabase.from('users').update({
        'church_id': churchId,
        'position_in_church': 'visitor',
        'church_name': churchData['church_name'],
      }).eq('id', currentUser.id);

      // Send notification to pastor
      await _sendVisitorNotification(churchId, currentUser.id);
    } catch (e) {
      print('Error registering as visitor: $e');
      rethrow;
    }
  }

  // Send visitor notification to pastor
  Future<void> _sendVisitorNotification(
      String churchId, String visitorId) async {
    try {
      final churchData = await getChurchById(churchId);
      if (churchData == null) return;

      final visitorData = await _getUserProfile(visitorId);
      if (visitorData == null) return;

      // Send push notification to pastor
      final notificationService = NotificationService();
      await notificationService.showCustomNotification(
        title: 'New Visitor',
        body:
            '${visitorData['name'] ?? 'A visitor'} has joined your church as a visitor',
        data: {
          'type': 'visitor',
          'church_id': churchId,
          'visitor_id': visitorId
        },
      );

      // Store in database for UI notifications
      await _supabase.from('notifications').insert({
        'user_id': churchData['pastor_id'],
        'type': 'visitor',
        'from_user_id': visitorId,
        'message':
            '${visitorData['name'] ?? 'A visitor'} has joined your church as a visitor',
        'data': {
          'church_id': churchId,
          'visitor_id': visitorId,
          'church_name': churchData['church_name'],
        },
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error sending visitor notification: $e');
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    try {
      final response =
          await _supabase.from('users').select().eq('id', userId).single();

      return response;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Get pastor notifications
  Stream<List<Map<String, dynamic>>> getPastorNotifications(String pastorId) {
    print('DEBUG ChurchService.getPastorNotifications: Getting notifications for pastorId: $pastorId');
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', pastorId)
        .order('created_at', ascending: false);
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
      rethrow;
    }
  }

  // Send invitation to visitor
  Future<void> sendInvitationToVisitor(
      String visitorId, String churchId, String message) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final churchData = await getChurchById(churchId);
      if (churchData == null) return;

      await _supabase.from('invitations').insert({
        'church_id': churchId,
        'pastor_id': currentUser.id,
        'visitor_id': visitorId,
        'message': message,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Send notification to visitor
      await _supabase.from('notifications').insert({
        'user_id': visitorId,
        'type': 'church_invitation',
        'from_user_id': currentUser.id,
        'message': 'You have been invited to join ${churchData['church_name']}',
        'data': {
          'church_id': churchId,
          'invitation_message': message,
        },
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error sending invitation: $e');
      rethrow;
    }
  }

  // Get user invitations
  Stream<List<Map<String, dynamic>>> getUserInvitations(String userId) {
    return _supabase
        .from('invitations')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data
            .where((invitation) =>
                invitation['visitor_id'] == userId &&
                invitation['status'] == 'pending')
            .toList());
  }

  // Accept invitation
  Future<void> acceptInvitation(String invitationId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Get invitation data
      final invitationData = await _supabase
          .from('invitations')
          .select()
          .eq('id', invitationId)
          .single();

      // Update invitation status
      await _supabase.from('invitations').update({
        'status': 'accepted',
        'accepted_at': DateTime.now().toIso8601String(),
      }).eq('id', invitationId);

      // Join the church
      await joinChurch(invitationData['church_id']);
    } catch (e) {
      print('Error accepting invitation: $e');
      rethrow;
    }
  }

  // Decline invitation
  Future<void> declineInvitation(String invitationId) async {
    try {
      await _supabase.from('invitations').update({
        'status': 'declined',
        'declined_at': DateTime.now().toIso8601String(),
      }).eq('id', invitationId);
    } catch (e) {
      print('Error declining invitation: $e');
      rethrow;
    }
  }

  // Upload church image
  Future<String?> uploadChurchImage(XFile imageFile, String churchId) async {
    try {
      final fileName =
          'church_images/${churchId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final fileBytes = await imageFile.readAsBytes();
      await _supabase.storage.from('church-images').uploadBinary(fileName, fileBytes);

      return _supabase.storage.from('church-images').getPublicUrl(fileName);
    } catch (e) {
      print('Error uploading church image: $e');
      return null;
    }
  }

  // Upload church profile picture
  Future<String?> uploadChurchProfilePicture(
      XFile imageFile, String churchId) async {
    print('DEBUG ChurchService.uploadChurchProfilePicture: Starting upload for churchId: $churchId');
    print('DEBUG ChurchService.uploadChurchProfilePicture: Image file path: ${imageFile.path}');
    print('DEBUG ChurchService.uploadChurchProfilePicture: Image file name: ${imageFile.name}');

    try {
      final fileName =
          'church_profile_pictures/${churchId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      print('DEBUG ChurchService.uploadChurchProfilePicture: Generated filename: $fileName');

      print('DEBUG ChurchService.uploadChurchProfilePicture: Reading file bytes...');
      final fileBytes = await imageFile.readAsBytes();
      print('DEBUG ChurchService.uploadChurchProfilePicture: File size: ${fileBytes.length} bytes');

      print('DEBUG ChurchService.uploadChurchProfilePicture: Attempting to upload to storage bucket...');
      await _supabase.storage
          .from('church-profile-pictures')
          .uploadBinary(fileName, fileBytes);
      print('DEBUG ChurchService.uploadChurchProfilePicture: Storage upload successful');

      final url = _supabase.storage
          .from('church-profile-pictures')
          .getPublicUrl(fileName);
      print('DEBUG ChurchService.uploadChurchProfilePicture: Generated public URL: $url');

      // Update church profile picture URL
      print('DEBUG ChurchService.uploadChurchProfilePicture: Updating church record in database...');
      print('DEBUG ChurchService.uploadChurchProfilePicture: Church ID: $churchId');
      print('DEBUG ChurchService.uploadChurchProfilePicture: New URL: $url');

      try {
        // First, let's check if the church exists
        final churchCheck = await _supabase.from('churches').select('id, profile_picture_url').eq('id', churchId);
        print('DEBUG ChurchService.uploadChurchProfilePicture: Church existence check result: $churchCheck');

        if (churchCheck.isEmpty) {
          print('DEBUG ChurchService.uploadChurchProfilePicture: ERROR - Church with ID $churchId does not exist!');
          return null;
        }

        print('DEBUG ChurchService.uploadChurchProfilePicture: Church exists, current profile_picture_url: ${churchCheck[0]['profile_picture_url']}');

        final updateResult = await _supabase.from('churches').update({
          'profile_picture_url': url,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', churchId).select();
        print('DEBUG ChurchService.uploadChurchProfilePicture: Database update result: $updateResult');
        if (updateResult.isEmpty) {
          print('DEBUG ChurchService.uploadChurchProfilePicture: WARNING - Database update returned empty result');
        } else {
          print('DEBUG ChurchService.uploadChurchProfilePicture: Database update successful');
          print('DEBUG ChurchService.uploadChurchProfilePicture: Updated church data: ${updateResult[0]}');
        }
      } catch (dbError) {
        print('DEBUG ChurchService.uploadChurchProfilePicture: Database update failed with error: $dbError');
        print('DEBUG ChurchService.uploadChurchProfilePicture: Error type: ${dbError.runtimeType}');
        if (dbError is PostgrestException) {
          print('DEBUG ChurchService.uploadChurchProfilePicture: Postgrest error code: ${dbError.code}');
          print('DEBUG ChurchService.uploadChurchProfilePicture: Postgrest error message: ${dbError.message}');
          print('DEBUG ChurchService.uploadChurchProfilePicture: Postgrest error details: ${dbError.details}');
          print('DEBUG ChurchService.uploadChurchProfilePicture: Postgrest error hint: ${dbError.hint}');
        }
        // Don't return null here, the file was uploaded successfully to storage
        // The issue is just with the database update
      }

      print('DEBUG ChurchService.uploadChurchProfilePicture: Upload process completed successfully');
      return url;
    } catch (e) {
      print('DEBUG ChurchService.uploadChurchProfilePicture: Error occurred: $e');
      print('DEBUG ChurchService.uploadChurchProfilePicture: Error type: ${e.runtimeType}');
      if (e is Exception) {
        print('DEBUG ChurchService.uploadChurchProfilePicture: Exception details: ${e.toString()}');
      }
      return null;
    }
  }

  // Upload church logo
  Future<String?> uploadChurchLogo(XFile logoFile, String churchId) async {
    try {
      final fileName =
          'church_logos/${churchId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final fileBytes = await logoFile.readAsBytes();
      await _supabase.storage.from('church-logos').uploadBinary(fileName, fileBytes);

      final url = _supabase.storage.from('church-logos').getPublicUrl(fileName);

      // Update church logo URL
      await _supabase.from('churches').update({
        'church_logo_url': url,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', churchId);

      return url;
    } catch (e) {
      print('Error uploading church logo: $e');
      return null;
    }
  }

  // Update church information
  Future<void> updateChurch(
      String churchId, Map<String, dynamic> updates) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Verify user is pastor of this church
      final churchData = await getChurchById(churchId);
      if (churchData == null || churchData['pastor_id'] != currentUser.id) {
        throw Exception('Unauthorized to update this church');
      }

      updates['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('churches').update(updates).eq('id', churchId);
    } catch (e) {
      print('Error updating church: $e');
      rethrow;
    }
  }

  // Get church members
  Stream<List<Map<String, dynamic>>> getChurchMembers(String churchId) {
    return _supabase
        .from('church_members')
        .stream(primaryKey: ['id'])
        .eq('church_id', churchId)
        .order('joined_at')
        .map((data) {
          final members = data.map((item) => item as Map<String, dynamic>).toList();
          // For now, return members as-is. The UI will handle missing user data gracefully
          return members;
        });
  }

  // Get church visitors
  Stream<List<Map<String, dynamic>>> getChurchVisitors(String churchId) {
    return _supabase
        .from('church_visitors')
        .stream(primaryKey: ['id'])
        .eq('church_id', churchId)
        .order('visited_at', ascending: false);
  }

  // Remove member from church
  Future<void> removeMember(String churchId, String memberId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Verify user is pastor of this church
      final churchData = await getChurchById(churchId);
      if (churchData == null || churchData['pastor_id'] != currentUser.id) {
        throw Exception('Unauthorized to remove members from this church');
      }

      // Remove from church members
      await _supabase
          .from('church_members')
          .delete()
          .eq('church_id', churchId)
          .eq('user_id', memberId);

      // Decrement member count
      await _supabase
          .rpc('decrement_church_members', params: {'church_id': churchId});

      // Update user's church status
      await _supabase.from('users').update({
        'church_id': null,
        'position_in_church': null,
        'church_name': null,
      }).eq('id', memberId);
    } catch (e) {
      print('Error removing member: $e');
      rethrow;
    }
  }

  // Get church statistics
  Future<Map<String, int>> getChurchStats(String churchId) async {
    try {
      print('DEBUG ChurchService.getChurchStats: Getting stats for churchId: $churchId');
      // Get members count
      final membersResponse = await _supabase
          .from('church_members')
          .select('id')
          .eq('church_id', churchId);

      print('DEBUG ChurchService.getChurchStats: membersResponse length: ${membersResponse.length}');
      print('DEBUG ChurchService.getChurchStats: membersResponse: $membersResponse');

      int visitorsCount = 0;
      try {
        // Get visitors count (table might not exist)
        final visitorsResponse = await _supabase
            .from('church_visitors')
            .select('id')
            .eq('church_id', churchId);
        visitorsCount = visitorsResponse.length;
        print('DEBUG ChurchService.getChurchStats: visitorsCount: $visitorsCount');
      } catch (e) {
        print('Church visitors table not found, skipping visitors count: $e');
      }

      int eventsCount = 0;
      try {
        // Get events count (table might not exist)
        final eventsResponse = await _supabase
            .from('church_events')
            .select('id')
            .eq('church_id', churchId);
        eventsCount = eventsResponse.length;
        print('DEBUG ChurchService.getChurchStats: eventsCount: $eventsCount');
      } catch (e) {
        print('Church events table not found, skipping events count: $e');
      }

      final result = {
        'members': membersResponse.length,
        'visitors': visitorsCount,
        'events': eventsCount,
      };
      print('DEBUG ChurchService.getChurchStats: returning: $result');
      return result;
    } catch (e) {
      print('Error getting church stats: $e');
      return {'members': 0, 'visitors': 0, 'events': 0};
    }
  }

  // Get churches by denomination
  Future<List<Map<String, dynamic>>> getChurchesByDenomination(
      String denomination) async {
    try {
      final response = await _supabase
          .from('churches')
          .select()
          .eq('denomination', denomination)
          .order('church_name')
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting churches by denomination: $e');
      return [];
    }
  }

  // Get nearby churches (requires location data)
  Future<List<Map<String, dynamic>>> getNearbyChurches(
      double latitude, double longitude,
      {double radiusKm = 10}) async {
    try {
      // This would require PostGIS extension in Supabase for proper geospatial queries
      // For now, return all churches (implement proper geospatial search later)
      final response = await _supabase
          .from('churches')
          .select()
          .order('church_name')
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting nearby churches: $e');
      return [];
    }
  }
}
