import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'notification_service.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class SupabaseChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();
  final _uuid = Uuid();

  // Initialize database tables
  Future<void> initializeTables() async {
    try {
      // Create group_message_reactions table if it doesn't exist
      await _supabase.rpc('create_group_message_reactions_table');
    } catch (e) {
      print('Error initializing tables: $e');
      // Try direct SQL execution as fallback
      try {
        await _createGroupMessageReactionsTable();
      } catch (e2) {
        print('Fallback table creation failed: $e2');
      }
    }
  }

  Future<void> _createGroupMessageReactionsTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS group_message_reactions (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        message_id UUID NOT NULL REFERENCES group_messages(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
        reaction_type TEXT NOT NULL DEFAULT 'love',
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(message_id, user_id, reaction_type)
      );

      CREATE INDEX IF NOT EXISTS idx_group_message_reactions_message_id ON group_message_reactions (message_id);
      CREATE INDEX IF NOT EXISTS idx_group_message_reactions_user_id ON group_message_reactions (user_id);
      CREATE INDEX IF NOT EXISTS idx_group_message_reactions_created_at ON group_message_reactions (created_at DESC);

      ALTER TABLE group_message_reactions ENABLE ROW LEVEL SECURITY;

      DROP POLICY IF EXISTS "Users can view reactions on group messages they can see" ON group_message_reactions;
      CREATE POLICY "Users can view reactions on group messages they can see" ON group_message_reactions
        FOR SELECT USING (
          EXISTS (
            SELECT 1 FROM group_messages gm
            JOIN groups g ON g.group_id = gm.group_id
            WHERE gm.id = group_message_reactions.message_id
            AND auth.uid() = ANY(g.participants)
          )
        );

      DROP POLICY IF EXISTS "Users can add reactions to group messages they can see" ON group_message_reactions;
      CREATE POLICY "Users can add reactions to group messages they can see" ON group_message_reactions
        FOR INSERT WITH CHECK (
          auth.uid() = user_id AND
          EXISTS (
            SELECT 1 FROM group_messages gm
            JOIN groups g ON g.group_id = gm.group_id
            WHERE gm.id = group_message_reactions.message_id
            AND auth.uid() = ANY(g.participants)
          )
        );

      DROP POLICY IF EXISTS "Users can remove their own reactions" ON group_message_reactions;
      CREATE POLICY "Users can remove their own reactions" ON group_message_reactions
        FOR DELETE USING (auth.uid() = user_id);
    ''';

    // Note: This won't work with standard Supabase client, but keeping as reference
    // In a real scenario, you'd need to execute this via a database function or manually
    print('Table creation SQL prepared but cannot execute via client');
  }

  // Send a text message to a chat between two users
  Future<void> sendMessage({
    required String toUserId,
    required String message,
    String messageType = 'text',
    String? mediaUrl,
    String? mediaPath,
    int? voiceDuration,
  }) async {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) return;

    final chatId = _getChatId(fromUser.id, toUserId);

    // Ensure chat exists
    await _ensureChatExists(chatId, fromUser.id, toUserId);

    // Prepare message data
    final messageData = {
      'chat_id': chatId,
      'sender_id': fromUser.id,
      'recipient_id': toUserId,
      'message': message,
      'message_type': messageType,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Add media-specific data
    if (mediaUrl != null) {
      messageData['media_url'] = mediaUrl;
    }
    if (voiceDuration != null) {
      messageData['voice_duration'] = voiceDuration.toString();
    }

    print('DEBUG: Attempting to insert message data: $messageData');
    print('DEBUG: Chat ID: $chatId');

    final result = await _supabase.from('messages').insert(messageData).select();
    print('DEBUG: Insert result: $result');

    // Send push notification to the recipient
    await _notificationService.sendPushNotification(
      userId: toUserId,
      title: 'New Message',
      body: message,
      data: {
        'type': 'chat_message',
        'from': fromUser.id,
        'to': toUserId,
        'chat_id': chatId,
        'message': message,
      },
    );
  }

  // Upload image to Supabase Storage
  Future<String> uploadImage(XFile imageFile) async {
    try {
      final fromUser = _supabase.auth.currentUser;
      if (fromUser == null) throw Exception('User not authenticated');

      final fileName =
          'chat_images/${fromUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // XFile.readAsBytes() works on both web and mobile
      final fileBytes = await imageFile.readAsBytes();

      final response = await _supabase.storage
          .from('chat-media')
          .uploadBinary(fileName, fileBytes);

      final publicUrl = _supabase.storage
          .from('chat-media')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // Upload video to Supabase Storage
  Future<String?> uploadVideo(XFile videoFile) async {
    try {
      final fromUser = _supabase.auth.currentUser;
      if (fromUser == null) return null;

      final fileName =
          'chat_videos/${fromUser.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final fileBytes = await videoFile.readAsBytes();

      final response = await _supabase.storage
          .from('chat-media')
          .uploadBinary(fileName, fileBytes);

      final publicUrl = _supabase.storage
          .from('chat-media')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }

  // Upload voice note to Supabase Storage
  Future<String> uploadVoiceNote(XFile audioFile) async {
    try {
      final fromUser = _supabase.auth.currentUser;
      if (fromUser == null) throw Exception('User not authenticated');

      final fileName =
          'chat_voice/${fromUser.id}_${DateTime.now().millisecondsSinceEpoch}.aac';
      final fileBytes = await audioFile.readAsBytes();

      final response = await _supabase.storage
          .from('chat-media')
          .uploadBinary(fileName, fileBytes);

      final publicUrl = _supabase.storage
          .from('chat-media')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print('Error uploading voice note: $e');
      throw Exception('Failed to upload voice note: $e');
    }
  }

  // Send image message
  Future<void> sendImageMessage({
    required String toUserId,
    required XFile imageFile,
    String? caption,
  }) async {
    final imageUrl = await uploadImage(imageFile);
    await sendMessage(
      toUserId: toUserId,
      message: caption ?? '📷 Image',
      messageType: 'image',
      mediaUrl: imageUrl,
    );
  }

  // Send video message
  Future<void> sendVideoMessage({
    required String toUserId,
    required XFile videoFile,
    String? caption,
  }) async {
    final videoUrl = await uploadVideo(videoFile);
    if (videoUrl != null) {
      await sendMessage(
        toUserId: toUserId,
        message: caption ?? '🎥 Video',
        messageType: 'video',
        mediaUrl: videoUrl,
      );
    }
  }

  // Send voice note message
  Future<void> sendVoiceMessage({
    required String toUserId,
    required XFile audioFile,
    required int durationInSeconds,
  }) async {
    final audioUrl = await uploadVoiceNote(audioFile);
    await sendMessage(
      toUserId: toUserId,
      message: '🎤 Voice message',
      messageType: 'voice',
      mediaUrl: audioUrl,
      voiceDuration: durationInSeconds,
    );
  }

  // Send emoji message
  Future<void> sendEmojiMessage({
    required String toUserId,
    required String emoji,
  }) async {
    await sendMessage(
      toUserId: toUserId,
      message: emoji,
      messageType: 'emoji',
    );
  }

  // Listen to messages in a chat
  Stream<List<Map<String, dynamic>>> getMessages(String otherUserId) {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) {
      return const Stream.empty();
    }
    final chatId = _getChatId(fromUser.id, otherUserId);

    return _supabase
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .order('timestamp', ascending: true)
        .asStream()
        .map((data) {
          print('DEBUG: Fetched messages data: $data');
          return List<Map<String, dynamic>>.from(data);
        });
  }

  // Stream chat metadata (last message, unread counts, etc.)
  Stream<Map<String, dynamic>?> chatMetaStream(String otherUserId) {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) {
      return const Stream.empty();
    }
    final chatId = _getChatId(fromUser.id, otherUserId);

    return _supabase
        .from('chats')
        .select()
        .eq('chat_id', chatId)
        .asStream()
        .map((data) => data.isNotEmpty ? data.first : null);
  }

  // Mark chat as read for current user (reset unread count)
  Future<void> markChatRead(String otherUserId) async {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) return;

    final chatId = _getChatId(fromUser.id, otherUserId);

    // Reset unread count for current user
    await _supabase.from('chats').update({
      'unread_counts': {
        fromUser.id: 0,
      },
    }).eq('chat_id', chatId);
  }

  // Typing indicators
  Future<void> setTyping(String otherUserId, bool isTyping) async {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) return;

    final chatId = _getChatId(fromUser.id, otherUserId);

    if (isTyping) {
      await _supabase.from('typing_indicators').upsert({
        'chat_id': chatId,
        'user_id': fromUser.id,
        'is_typing': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      await _supabase
          .from('typing_indicators')
          .delete()
          .eq('chat_id', chatId)
          .eq('user_id', fromUser.id);
    }
  }

  Stream<Map<String, dynamic>?> otherUserTypingStream(String otherUserId) {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) {
      return const Stream.empty();
    }
    final chatId = _getChatId(fromUser.id, otherUserId);

    return _supabase
        .from('typing_indicators')
        .select()
        .eq('chat_id', chatId)
        .eq('user_id', otherUserId)
        .asStream()
        .map((data) => data.isNotEmpty ? data.first : null);
  }

  // Helper to get a unique chat id for two users
  String _getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // Ensure chat exists
  Future<void> _ensureChatExists(String chatId, String uid1, String uid2) async {
    final existingChat = await _supabase
        .from('chats')
        .select()
        .eq('chat_id', chatId)
        .maybeSingle();

    if (existingChat == null) {
      await _supabase.from('chats').insert({
        'chat_id': chatId,
        'participants': [uid1, uid2],
      });
    }
  }

  // Public method to ensure chat exists
  Future<void> ensureChatExists(String otherUserId) async {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) return;

    final chatId = _getChatId(fromUser.id, otherUserId);
    await _ensureChatExists(chatId, fromUser.id, otherUserId);
  }

  // Send a message to a group chat
  Future<void> sendGroupMessage({
    required String groupId,
    required String message,
    required String groupType,
    String messageType = 'text',
    String? mediaUrl,
    String? mediaPath,
    int? voiceDuration,
  }) async {
    print('DEBUG: sendGroupMessage called with groupId: $groupId, messageType: $messageType');
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) {
      print('DEBUG: No authenticated user for group message');
      return;
    }
    print('DEBUG: Authenticated user for group message: ${fromUser.id}');

    // Prepare message data
    final messageData = {
      'group_id': groupId,
      'sender_id': fromUser.id,
      'message': message,
      'message_type': messageType,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Add media-specific data
    if (mediaUrl != null) {
      messageData['media_url'] = mediaUrl;
    }
    if (voiceDuration != null) {
      messageData['voice_duration'] = voiceDuration.toString();
    }

    print('DEBUG: Inserting group message data: $messageData');
    try {
      final result = await _supabase.from('group_messages').insert(messageData).select();
      print('DEBUG: Group message insert result: $result');
    } catch (e) {
      print('DEBUG: Error inserting group message: $e');
      throw e;
    }

    // Send push notifications to all group members except the sender
    try {
      final group = await _supabase
          .from('groups')
          .select('participants')
          .eq('group_id', groupId)
          .single();

      final participants = List<String>.from(group['participants'] ?? []);
      final recipientIds = participants.where((id) => id != fromUser.id).toList();

      if (recipientIds.isNotEmpty) {
        await _notificationService.sendNotificationToUsers(
          userIds: recipientIds,
          title: 'New Group Message',
          body: message,
          data: {
            'type': 'group_message',
            'groupId': groupId,
            'senderId': fromUser.id,
            'message': message,
            'groupType': groupType,
          },
        );
      }
    } catch (e) {
      print('Error sending group notifications: $e');
    }
  }

  // Listen to messages in a group chat
  Stream<List<Map<String, dynamic>>> getGroupMessages(String groupId) {
    print('DEBUG: Setting up group messages stream for groupId: $groupId');

    // Create a stream controller for real-time updates
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    // Initial fetch
    _fetchMessages(groupId).then((messages) {
      print('DEBUG: Initial fetch: ${messages.length} messages');
      controller.add(messages);
    }).catchError((error) {
      print('DEBUG: Error in initial fetch: $error');
      controller.addError(error);
    });

    // Set up real-time subscription
    final channel = _supabase.channel('group_messages_$groupId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'group_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'group_id',
          value: groupId,
        ),
        callback: (payload) async {
          print('DEBUG: Real-time change detected: ${payload.eventType}');
          try {
            final messages = await _fetchMessages(groupId);
            print('DEBUG: Real-time update: ${messages.length} messages');
            controller.add(messages);
          } catch (error) {
            print('DEBUG: Error in real-time fetch: $error');
            controller.addError(error);
          }
        },
      )
      ..subscribe();

    // Clean up on controller close
    controller.onCancel = () {
      print('DEBUG: Closing stream for groupId: $groupId');
      _supabase.removeChannel(channel);
    };

    return controller.stream;
  }

  // Helper method to fetch messages
  Future<List<Map<String, dynamic>>> _fetchMessages(String groupId) async {
    final data = await _supabase
        .from('group_messages')
        .select()
        .eq('group_id', groupId)
        .order('timestamp', ascending: true);

    final messages = List<Map<String, dynamic>>.from(data);
    final types = messages.map((m) => m['message_type']).toSet();
    print('DEBUG: Fetched messages: ${messages.length}, types: $types');
    return messages;
  }

  // Upload group image to Supabase Storage
  Future<String?> uploadGroupImage(XFile imageFile, String groupId) async {
    try {
      print('DEBUG: Starting group image upload for group: $groupId');
      final fromUser = _supabase.auth.currentUser;
      if (fromUser == null) {
        print('DEBUG: No authenticated user for image upload');
        return null;
      }
      print('DEBUG: Authenticated user: ${fromUser.id}');

      final fileName =
          'group_images/${groupId}/${fromUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      print('DEBUG: Upload file name: $fileName');

      final fileBytes = await imageFile.readAsBytes();
      print('DEBUG: File size: ${fileBytes.length} bytes');

      print('DEBUG: Uploading to chat-media bucket...');
      final response = await _supabase.storage
          .from('chat-media')
          .uploadBinary(fileName, fileBytes);
      print('DEBUG: Upload response: $response');

      final publicUrl = _supabase.storage
          .from('chat-media')
          .getPublicUrl(fileName);
      print('DEBUG: Generated public URL: $publicUrl');

      return publicUrl;
    } catch (e) {
      print('DEBUG: Error uploading group image: $e');
      return null;
    }
  }

  // Upload group video to Supabase Storage
  Future<String?> uploadGroupVideo(XFile videoFile, String groupId) async {
    try {
      final fromUser = _supabase.auth.currentUser;
      if (fromUser == null) return null;

      final fileName =
          'group_videos/${groupId}/${fromUser.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final fileBytes = await videoFile.readAsBytes();

      final response = await _supabase.storage
          .from('chat-media')
          .uploadBinary(fileName, fileBytes);

      final publicUrl = _supabase.storage
          .from('chat-media')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print('Error uploading group video: $e');
      return null;
    }
  }

  // Upload group voice note to Supabase Storage
  Future<String?> uploadGroupVoiceNote(XFile audioFile, String groupId) async {
    try {
      final fromUser = _supabase.auth.currentUser;
      if (fromUser == null) return null;

      final fileName =
          'group_voice/${groupId}/${fromUser.id}_${DateTime.now().millisecondsSinceEpoch}.aac';
      final fileBytes = await audioFile.readAsBytes();

      final response = await _supabase.storage
          .from('chat-media')
          .uploadBinary(fileName, fileBytes);

      final publicUrl = _supabase.storage
          .from('chat-media')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print('Error uploading group voice note: $e');
      return null;
    }
  }

  // Send group image message
  Future<void> sendGroupImageMessage({
    required String groupId,
    required XFile imageFile,
    required String groupType,
    String? caption,
  }) async {
    print('DEBUG: Starting sendGroupImageMessage for group: $groupId, type: $groupType');
    final imageUrl = await uploadGroupImage(imageFile, groupId);
    print('DEBUG: Uploaded image URL: $imageUrl');
    if (imageUrl != null) {
      print('DEBUG: Image uploaded successfully, sending message...');
      await sendGroupMessage(
        groupId: groupId,
        message: caption ?? '📷 Image',
        groupType: groupType,
        messageType: 'image',
        mediaUrl: imageUrl,
      );
      print('DEBUG: Group image message sent successfully');
    } else {
      print('DEBUG: Failed to upload image, message not sent');
    }
  }

  // Send group video message
  Future<void> sendGroupVideoMessage({
    required String groupId,
    required XFile videoFile,
    required String groupType,
    String? caption,
  }) async {
    final videoUrl = await uploadGroupVideo(videoFile, groupId);
    if (videoUrl != null) {
      await sendGroupMessage(
        groupId: groupId,
        message: caption ?? '🎥 Video',
        groupType: groupType,
        messageType: 'video',
        mediaUrl: videoUrl,
      );
    }
  }

  // Send group voice note message
  Future<void> sendGroupVoiceMessage({
    required String groupId,
    required XFile audioFile,
    required int durationInSeconds,
    required String groupType,
  }) async {
    final audioUrl = await uploadGroupVoiceNote(audioFile, groupId);
    if (audioUrl != null) {
      await sendGroupMessage(
        groupId: groupId,
        message: '🎤 Voice message',
        groupType: groupType,
        messageType: 'voice',
        mediaUrl: audioUrl,
        voiceDuration: durationInSeconds,
      );
    }
  }

  // Send group emoji message
  Future<void> sendGroupEmojiMessage({
    required String groupId,
    required String emoji,
    required String groupType,
  }) async {
    await sendGroupMessage(
      groupId: groupId,
      message: emoji,
      groupType: groupType,
      messageType: 'emoji',
    );
  }

  // Update message (for edit functionality)
  Future<void> updateMessage(String messageId, String newText) async {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) return;

    try {
      // Find the message in messages table
      final message = await _supabase
          .from('messages')
          .select()
          .eq('id', messageId)
          .single();

      // Only allow editing own messages
      if (message['sender_id'] == fromUser.id) {
        await _supabase.from('messages').update({
          'message': newText,
          'edited': true,
          'edited_at': DateTime.now().toIso8601String(),
        }).eq('id', messageId);
      }
    } catch (e) {
      print('Error updating message: $e');
      throw Exception('Failed to update message');
    }
  }

  // Delete message (for unsend functionality)
  Future<void> deleteMessage(String messageId) async {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) return;

    try {
      // Find the message in messages table
      final message = await _supabase
          .from('messages')
          .select()
          .eq('id', messageId)
          .single();

      // Only allow deleting own messages
      if (message['sender_id'] == fromUser.id) {
        await _supabase.from('messages').update({
          'message': 'This message was unsent',
          'message_type': 'deleted',
          'deleted': true,
          'deleted_at': DateTime.now().toIso8601String(),
        }).eq('id', messageId);
      }
    } catch (e) {
      print('Error deleting message: $e');
      throw Exception('Failed to delete message');
    }
  }

  // Pin message
  Future<void> pinMessage(String messageId, String chatId) async {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) return;

    try {
      await _supabase.from('messages').update({
        'pinned': true,
        'pinned_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId);
    } catch (e) {
      print('Error pinning message: $e');
      throw Exception('Failed to pin message');
    }
  }

  // Unpin message
  Future<void> unpinMessage(String messageId, String chatId) async {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) return;

    try {
      await _supabase.from('messages').update({
        'pinned': false,
        'pinned_at': null,
      }).eq('id', messageId);
    } catch (e) {
      print('Error unpinning message: $e');
      throw Exception('Failed to unpin message');
    }
  }

  // Get user conversations (list of chats for current user)
  Stream<List<Map<String, dynamic>>> getUserConversations() {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) {
      return const Stream.empty();
    }

    return _supabase
        .from('chats')
        .select()
        .contains('participants', [fromUser.id])
        .order('last_message_timestamp', ascending: false)
        .asStream()
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // Toggle love reaction on a message
  Future<void> toggleLoveReaction(String messageId) async {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) return;

    try {
      // Check if reaction already exists
      final existingReaction = await _supabase
          .from('message_reactions')
          .select()
          .eq('message_id', messageId)
          .eq('user_id', fromUser.id)
          .eq('reaction_type', 'love')
          .maybeSingle();

      if (existingReaction != null) {
        // Remove reaction
        await _supabase
            .from('message_reactions')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', fromUser.id)
            .eq('reaction_type', 'love');
      } else {
        // Add reaction
        await _supabase.from('message_reactions').insert({
          'message_id': messageId,
          'user_id': fromUser.id,
          'reaction_type': 'love',
        });
      }
    } catch (e) {
      print('Error toggling love reaction: $e');
      throw Exception('Failed to toggle love reaction');
    }
  }

  // Get reactions for a message
  Future<List<Map<String, dynamic>>> getMessageReactions(String messageId) async {
    try {
      final data = await _supabase
          .from('message_reactions')
          .select('reaction_type, user_id, created_at')
          .eq('message_id', messageId);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error getting message reactions: $e');
      return [];
    }
  }

  // Stream reactions for a message
  Stream<List<Map<String, dynamic>>> getMessageReactionsStream(String messageId) {
    return _supabase
        .from('message_reactions')
        .select('reaction_type, user_id, created_at')
        .eq('message_id', messageId)
        .order('created_at', ascending: true)
        .asStream()
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // Toggle love reaction on a group message
  Future<void> toggleGroupLoveReaction(String messageId) async {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) return;

    try {
      // Check if reaction already exists
      final existingReaction = await _supabase
          .from('group_message_reactions')
          .select()
          .eq('message_id', messageId)
          .eq('user_id', fromUser.id)
          .eq('reaction_type', 'love')
          .maybeSingle();

      if (existingReaction != null) {
        // Remove reaction
        await _supabase
            .from('group_message_reactions')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', fromUser.id)
            .eq('reaction_type', 'love');
      } else {
        // Add reaction
        await _supabase.from('group_message_reactions').insert({
          'message_id': messageId,
          'user_id': fromUser.id,
          'reaction_type': 'love',
        });
      }
    } catch (e) {
      print('Error toggling group love reaction: $e');
      throw Exception('Failed to toggle group love reaction');
    }
  }

  // Get reactions for a group message
  Future<List<Map<String, dynamic>>> getGroupMessageReactions(String messageId) async {
    try {
      final data = await _supabase
          .from('group_message_reactions')
          .select('reaction_type, user_id, created_at')
          .eq('message_id', messageId);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error getting group message reactions: $e');
      return [];
    }
  }

  // Stream reactions for a group message
  Stream<List<Map<String, dynamic>>> getGroupMessageReactionsStream(String messageId) {
    return _supabase
        .from('group_message_reactions')
        .select('reaction_type, user_id, created_at')
        .eq('message_id', messageId)
        .order('created_at', ascending: true)
        .asStream()
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // Add reaction to a message (for swipe reactions)
  Future<void> addMessageReaction(String messageId, String reactionType) async {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) return;

    try {
      await _supabase.from('message_reactions').insert({
        'message_id': messageId,
        'user_id': fromUser.id,
        'reaction_type': reactionType,
      });
    } catch (e) {
      print('Error adding message reaction: $e');
      throw Exception('Failed to add message reaction');
    }
  }

  // Add reaction to a group message (for swipe reactions)
  Future<void> addGroupMessageReaction(String messageId, String reactionType) async {
    final fromUser = _supabase.auth.currentUser;
    if (fromUser == null) return;

    try {
      await _supabase.from('group_message_reactions').insert({
        'message_id': messageId,
        'user_id': fromUser.id,
        'reaction_type': reactionType,
      });
    } catch (e) {
      print('Error adding group message reaction: $e');
      throw Exception('Failed to add group message reaction');
    }
  }
}
