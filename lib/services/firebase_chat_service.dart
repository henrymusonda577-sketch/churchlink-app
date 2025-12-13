import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'notification_service.dart';

class FirebaseChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final NotificationService _notificationService = NotificationService();

  // Send a text message to a chat between two users
  Future<void> sendMessage({
    required String toUserId,
    required String message,
    String messageType = 'text',
    String? mediaUrl,
    String? mediaPath,
    int? voiceDuration,
  }) async {
    final fromUser = _auth.currentUser;
    if (fromUser == null) return;

    final chatId = _getChatId(fromUser.uid, toUserId);
    final chatDocRef = _firestore.collection('chats').doc(chatId);
    final messagesColRef = chatDocRef.collection('messages');

    // Prepare message data
    final messageData = {
      'from': fromUser.uid,
      'to': toUserId,
      'message': message,
      'messageType': messageType,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Add media-specific data
    if (mediaUrl != null) {
      messageData['mediaUrl'] = mediaUrl;
    }
    if (voiceDuration != null) {
      messageData['voiceDuration'] = voiceDuration;
    }

    await _firestore.runTransaction((txn) async {
      txn.set(messagesColRef.doc(), messageData);
      txn.set(
        chatDocRef,
        {
          'participants': [fromUser.uid, toUserId],
          'lastMessage': message,
          'lastMessageType': messageType,
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'unreadCounts': {
            toUserId: FieldValue.increment(1),
          },
        },
        SetOptions(merge: true),
      );
      // Mark sender as not typing after sending
      txn.set(
        chatDocRef.collection('typing').doc(fromUser.uid),
        {
          'isTyping': false,
          'timestamp': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    // Send notification to the recipient
    await _notificationService.showCustomNotification(
      title: 'New Message',
      body: message,
      data: {
        'type': 'chat_message',
        'from': fromUser.uid,
        'to': toUserId,
        'message': message,
      },
    );
  }

  // Upload image to Firebase Storage
  Future<String> uploadImage(File imageFile) async {
    try {
      final fromUser = _auth.currentUser;
      if (fromUser == null) throw Exception('User not authenticated');

      final fileName =
          'chat_images/${fromUser.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // Upload video to Firebase Storage
  Future<String?> uploadVideo(File videoFile) async {
    try {
      final fromUser = _auth.currentUser;
      if (fromUser == null) return null;

      final fileName =
          'chat_videos/${fromUser.uid}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putFile(videoFile);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }

  // Upload voice note to Firebase Storage
  Future<String> uploadVoiceNote(File audioFile) async {
    try {
      final fromUser = _auth.currentUser;
      if (fromUser == null) throw Exception('User not authenticated');

      final fileName =
          'chat_voice/${fromUser.uid}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putFile(audioFile);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading voice note: $e');
      throw Exception('Failed to upload voice note: $e');
    }
  }

  // Send image message
  Future<void> sendImageMessage({
    required String toUserId,
    required File imageFile,
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
    required File videoFile,
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
    required File audioFile,
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
  Stream<QuerySnapshot> getMessages(String otherUserId) {
    final fromUser = _auth.currentUser;
    if (fromUser == null) {
      return const Stream.empty();
    }
    final chatId = _getChatId(fromUser.uid, otherUserId);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Stream chat metadata (last message, unread counts, etc.)
  Stream<DocumentSnapshot<Map<String, dynamic>>> chatMetaStream(
      String otherUserId) {
    final fromUser = _auth.currentUser;
    if (fromUser == null) {
      return const Stream.empty();
    }
    final chatId = _getChatId(fromUser.uid, otherUserId);
    return _firestore.collection('chats').doc(chatId).snapshots();
  }

  // Mark chat as read for current user (reset unread count)
  Future<void> markChatRead(String otherUserId) async {
    final fromUser = _auth.currentUser;
    if (fromUser == null) return;
    final chatId = _getChatId(fromUser.uid, otherUserId);
    await _firestore.collection('chats').doc(chatId).set(
      {
        'unreadCounts': {fromUser.uid: 0},
      },
      SetOptions(merge: true),
    );
  }

  // Typing indicators
  Future<void> setTyping(String otherUserId, bool isTyping) async {
    final fromUser = _auth.currentUser;
    if (fromUser == null) return;
    final chatId = _getChatId(fromUser.uid, otherUserId);
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .doc(fromUser.uid)
        .set(
      {
        'isTyping': isTyping,
        'timestamp': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> otherUserTypingStream(
      String otherUserId) {
    final fromUser = _auth.currentUser;
    if (fromUser == null) {
      return const Stream.empty();
    }
    final chatId = _getChatId(fromUser.uid, otherUserId);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .doc(otherUserId)
        .snapshots();
  }

  // Helper to get a unique chat id for two users
  String _getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
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
    final fromUser = _auth.currentUser;
    if (fromUser == null) return;

    final groupDocRef = _firestore.collection('groups').doc(groupId);
    final messagesColRef = groupDocRef.collection('messages');

    // Prepare message data
    final messageData = {
      'senderId': fromUser.uid,
      'message': message,
      'messageType': messageType,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Add media-specific data
    if (mediaUrl != null) {
      messageData['mediaUrl'] = mediaUrl;
    }
    if (voiceDuration != null) {
      messageData['voiceDuration'] = voiceDuration;
    }

    await _firestore.runTransaction((txn) async {
      txn.set(messagesColRef.doc(), messageData);
      txn.set(
        groupDocRef,
        {
          'lastMessage': message,
          'lastMessageSenderId': fromUser.uid,
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'groupType': groupType,
        },
        SetOptions(merge: true),
      );
    });

    // Send notification to group members
    await _notificationService.showCustomNotification(
      title: 'New Group Message',
      body: message,
      data: {
        'type': 'group_message',
        'groupId': groupId,
        'senderId': fromUser.uid,
        'message': message,
        'groupType': groupType,
      },
    );
  }

  // Listen to messages in a group chat
  Stream<QuerySnapshot> getGroupMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Upload group image to Firebase Storage
  Future<String?> uploadGroupImage(File imageFile, String groupId) async {
    try {
      final fromUser = _auth.currentUser;
      if (fromUser == null) return null;

      final fileName =
          'group_images/${groupId}/${fromUser.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading group image: $e');
      return null;
    }
  }

  // Upload group video to Firebase Storage
  Future<String?> uploadGroupVideo(File videoFile, String groupId) async {
    try {
      final fromUser = _auth.currentUser;
      if (fromUser == null) return null;

      final fileName =
          'group_videos/${groupId}/${fromUser.uid}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putFile(videoFile);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading group video: $e');
      return null;
    }
  }

  // Upload group voice note to Firebase Storage
  Future<String?> uploadGroupVoiceNote(File audioFile, String groupId) async {
    try {
      final fromUser = _auth.currentUser;
      if (fromUser == null) return null;

      final fileName =
          'group_voice/${groupId}/${fromUser.uid}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putFile(audioFile);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading group voice note: $e');
      return null;
    }
  }

  // Send group image message
  Future<void> sendGroupImageMessage({
    required String groupId,
    required File imageFile,
    required String groupType,
    String? caption,
  }) async {
    final imageUrl = await uploadGroupImage(imageFile, groupId);
    if (imageUrl != null) {
      await sendGroupMessage(
        groupId: groupId,
        message: caption ?? '📷 Image',
        groupType: groupType,
        messageType: 'image',
        mediaUrl: imageUrl,
      );
    }
  }

  // Send group video message
  Future<void> sendGroupVideoMessage({
    required String groupId,
    required File videoFile,
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
    required File audioFile,
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
    final fromUser = _auth.currentUser;
    if (fromUser == null) return;

    try {
      // Find the message in all possible chat collections
      final chatsQuery = await _firestore.collection('chats').get();

      for (final chatDoc in chatsQuery.docs) {
        final messageDoc =
            await chatDoc.reference.collection('messages').doc(messageId).get();

        if (messageDoc.exists) {
          final messageData = messageDoc.data()!;
          // Only allow editing own messages
          if (messageData['from'] == fromUser.uid) {
            await messageDoc.reference.update({
              'message': newText,
              'edited': true,
              'editedAt': FieldValue.serverTimestamp(),
            });
            return;
          }
        }
      }

      // Also check group messages
      final groupsQuery = await _firestore.collection('groups').get();

      for (final groupDoc in groupsQuery.docs) {
        final messageDoc = await groupDoc.reference
            .collection('messages')
            .doc(messageId)
            .get();

        if (messageDoc.exists) {
          final messageData = messageDoc.data()!;
          // Only allow editing own messages
          if (messageData['senderId'] == fromUser.uid) {
            await messageDoc.reference.update({
              'message': newText,
              'edited': true,
              'editedAt': FieldValue.serverTimestamp(),
            });
            return;
          }
        }
      }
    } catch (e) {
      print('Error updating message: $e');
      throw Exception('Failed to update message');
    }
  }

  // Delete message (for unsend functionality)
  Future<void> deleteMessage(String messageId) async {
    final fromUser = _auth.currentUser;
    if (fromUser == null) return;

    try {
      // Find the message in all possible chat collections
      final chatsQuery = await _firestore.collection('chats').get();

      for (final chatDoc in chatsQuery.docs) {
        final messageDoc =
            await chatDoc.reference.collection('messages').doc(messageId).get();

        if (messageDoc.exists) {
          final messageData = messageDoc.data()!;
          // Only allow deleting own messages
          if (messageData['from'] == fromUser.uid) {
            await messageDoc.reference.update({
              'message': 'This message was unsent',
              'messageType': 'deleted',
              'deleted': true,
              'deletedAt': FieldValue.serverTimestamp(),
            });
            return;
          }
        }
      }

      // Also check group messages
      final groupsQuery = await _firestore.collection('groups').get();

      for (final groupDoc in groupsQuery.docs) {
        final messageDoc = await groupDoc.reference
            .collection('messages')
            .doc(messageId)
            .get();

        if (messageDoc.exists) {
          final messageData = messageDoc.data()!;
          // Only allow deleting own messages
          if (messageData['senderId'] == fromUser.uid) {
            await messageDoc.reference.update({
              'message': 'This message was unsent',
              'messageType': 'deleted',
              'deleted': true,
              'deletedAt': FieldValue.serverTimestamp(),
            });
            return;
          }
        }
      }
    } catch (e) {
      print('Error deleting message: $e');
      throw Exception('Failed to delete message');
    }
  }

  // Pin message
  Future<void> pinMessage(String messageId, String chatId) async {
    final fromUser = _auth.currentUser;
    if (fromUser == null) return;

    try {
      await _firestore.collection('chats').doc(chatId).update({
        'pinnedMessages': FieldValue.arrayUnion([messageId]),
      });
    } catch (e) {
      print('Error pinning message: $e');
      throw Exception('Failed to pin message');
    }
  }

  // Unpin message
  Future<void> unpinMessage(String messageId, String chatId) async {
    final fromUser = _auth.currentUser;
    if (fromUser == null) return;

    try {
      await _firestore.collection('chats').doc(chatId).update({
        'pinnedMessages': FieldValue.arrayRemove([messageId]),
      });
    } catch (e) {
      print('Error unpinning message: $e');
      throw Exception('Failed to unpin message');
    }
  }

  // Get user conversations (list of chats for current user)
  Stream<QuerySnapshot> getUserConversations() {
    final fromUser = _auth.currentUser;
    if (fromUser == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: fromUser.uid)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots();
  }
}
