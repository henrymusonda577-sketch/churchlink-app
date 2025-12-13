import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'notification_service.dart';
import 'user_service.dart';

class ContentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final NotificationService _notificationService = NotificationService();

  // Post a new prayer
  Future<void> postPrayer({
    required String title,
    required String prayer,
    required String authorId,
    required String authorName,
  }) async {
    try {
      print('Posting prayer: $title');
      print('Prayer content length: ${prayer.length}');

      final prayerRef = await _firestore.collection('prayers').add({
        'title': title,
        'prayer': prayer,
        'authorId': authorId,
        'authorName': authorName,
        'likes': 0,
        'comments': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Prayer posted successfully with ID: ${prayerRef.id}');

      // Send notification to church members about new prayer
      await _sendPrayerNotification(prayerRef.id, title, authorName);
    } catch (e) {
      print('Error posting prayer: $e');
      print('Stack trace: ${e.toString()}');
      rethrow;
    }
  }

  // Like a prayer
  Future<void> likePrayer(
      String prayerId, String userId, String userName) async {
    final prayerDoc =
        await _firestore.collection('prayers').doc(prayerId).get();
    if (prayerDoc.exists) {
      final prayerData = prayerDoc.data()!;
      final likes = List<String>.from(prayerData['likes'] ?? []);

      if (!likes.contains(userId)) {
        likes.add(userId);

        await _firestore.collection('prayers').doc(prayerId).update({
          'likes': likes,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Send notification to prayer author about the like
        if (prayerData['authorId'] != userId) {
          await _sendLikeNotification(prayerId, prayerData['title'] ?? 'Prayer',
              userName, prayerData['authorId'], 'prayer');
        }
      }
    }
  }

  // Post a comment on prayer
  Future<void> postComment({
    required String prayerId,
    required String text,
    required String authorId,
    required String authorName,
  }) async {
    final commentData = {
      'text': text,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('prayers').doc(prayerId).update({
      'comments': FieldValue.arrayUnion([commentData]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Send notification to prayer author about the comment
    final prayerDoc =
        await _firestore.collection('prayers').doc(prayerId).get();
    if (prayerDoc.exists) {
      final prayerData = prayerDoc.data()!;
      if (prayerData['authorId'] != authorId) {
        await _sendCommentNotification(
            prayerId,
            prayerData['title'] ?? 'Prayer',
            authorName,
            prayerData['authorId'],
            'prayer');
      }
    }
  }

  // Upload and post video
  Future<void> postVideo(
    File videoFile, {
    String? caption,
    required String authorId,
    required String authorName,
  }) async {
    final videoUrl = await _uploadVideo(videoFile);
    if (videoUrl != null) {
      final videoRef = await _firestore.collection('videos').add({
        'videoUrl': videoUrl,
        'caption': caption,
        'authorId': authorId,
        'authorName': authorName,
        'likes': 0,
        'comments': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to church members about new video
      await _sendVideoNotification(
          videoRef.id, caption ?? 'New video', authorName);
    }
  }

  // Like a video
  Future<void> likeVideo(String videoId, String userId, String userName) async {
    final videoDoc = await _firestore.collection('videos').doc(videoId).get();
    if (videoDoc.exists) {
      final videoData = videoDoc.data()!;
      final likes = List<String>.from(videoData['likes'] ?? []);

      if (!likes.contains(userId)) {
        likes.add(userId);

        await _firestore.collection('videos').doc(videoId).update({
          'likes': likes,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Send notification to video author about the like
        if (videoData['authorId'] != userId) {
          await _sendLikeNotification(videoId, videoData['caption'] ?? 'Video',
              userName, videoData['authorId'], 'video');
        }
      }
    }
  }

  // Post a comment on video
  Future<void> postVideoComment({
    required String videoId,
    required String text,
    required String authorId,
    required String authorName,
  }) async {
    final commentData = {
      'text': text,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('videos').doc(videoId).update({
      'comments': FieldValue.arrayUnion([commentData]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Send notification to video author about the comment
    final videoDoc = await _firestore.collection('videos').doc(videoId).get();
    if (videoDoc.exists) {
      final videoData = videoDoc.data()!;
      if (videoData['authorId'] != authorId) {
        await _sendCommentNotification(videoId, videoData['caption'] ?? 'Video',
            authorName, videoData['authorId'], 'video');
      }
    }
  }

  // Create event
  Future<void> createEvent(Map<String, dynamic> eventData) async {
    final eventRef = await _firestore.collection('events').add({
      ...eventData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Send notification to church members about new event
    await _sendEventNotification(
        eventRef.id, eventData['title'], eventData['organizer']);
  }

  // RSVP to event
  Future<void> rsvpToEvent(
      String eventId, String userId, String userName) async {
    await _firestore.collection('events').doc(eventId).update({
      'rsvps': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Send notification to event organizer about RSVP
    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (eventDoc.exists) {
      final eventData = eventDoc.data()!;
      if (eventData['organizerId'] != userId) {
        await _sendRsvpNotification(
            eventId, eventData['title'], userName, eventData['organizerId']);
      }
    }
  }

  // Upload video to storage
  Future<String?> _uploadVideo(File videoFile) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // Get the original file extension
      final extension = videoFile.path.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'videos/${currentUser.uid}_${timestamp}.$extension';
      final ref = _storage.ref().child(fileName);

      // Set appropriate content type based on file extension
      String contentType;
      switch (extension) {
        case 'mp4':
          contentType = 'video/mp4';
          break;
        case 'avi':
          contentType = 'video/x-msvideo';
          break;
        case 'mov':
          contentType = 'video/quicktime';
          break;
        case 'mkv':
          contentType = 'video/x-matroska';
          break;
        case 'webm':
          contentType = 'video/webm';
          break;
        case 'flv':
          contentType = 'video/x-flv';
          break;
        case 'wmv':
          contentType = 'video/x-ms-wmv';
          break;
        case 'm4v':
          contentType = 'video/x-m4v';
          break;
        case '3gp':
          contentType = 'video/3gpp';
          break;
        default:
          contentType = 'video/mp4'; // fallback
      }

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedBy': currentUser.uid,
          'uploadedAt': timestamp.toString(),
          'originalExtension': extension,
        },
      );

      final uploadTask = ref.putFile(videoFile, metadata);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }

  // Notification methods
  Future<void> _sendPrayerNotification(
      String prayerId, String title, String authorName) async {
    final userService = UserService();
    final churchMembers = await userService.getChurchMembers();

    for (final member in churchMembers) {
      if (member['userId'] != _auth.currentUser?.uid) {
        await _notificationService.showCustomNotification(
          title: 'New Prayer Posted',
          body: '$authorName posted a new prayer: "$title"',
          data: {
            'type': 'prayer_post',
            'prayerId': prayerId,
            'authorName': authorName,
          },
        );
      }
    }
  }

  Future<void> _sendVideoNotification(
      String videoId, String caption, String authorName) async {
    final userService = UserService();
    final churchMembers = await userService.getChurchMembers();

    for (final member in churchMembers) {
      if (member['userId'] != _auth.currentUser?.uid) {
        await _notificationService.showCustomNotification(
          title: 'New Video Posted',
          body: '$authorName posted a new video: "$caption"',
          data: {
            'type': 'video_post',
            'videoId': videoId,
            'authorName': authorName,
          },
        );
      }
    }
  }

  Future<void> _sendEventNotification(
      String eventId, String title, String organizerName) async {
    final userService = UserService();
    final churchMembers = await userService.getChurchMembers();

    for (final member in churchMembers) {
      if (member['userId'] != _auth.currentUser?.uid) {
        await _notificationService.showCustomNotification(
          title: 'New Event Created',
          body: '$organizerName created a new event: "$title"',
          data: {
            'type': 'event_created',
            'eventId': eventId,
            'organizerName': organizerName,
          },
        );
      }
    }
  }

  Future<void> _sendLikeNotification(String itemId, String itemTitle,
      String likerName, String authorId, String itemType) async {
    await _notificationService.showCustomNotification(
      title: 'New Like',
      body: '$likerName liked your $itemType: "$itemTitle"',
      data: {
        'type': '${itemType}_like',
        'itemId': itemId,
        'likerName': likerName,
        'authorId': authorId,
      },
    );
  }

  Future<void> _sendCommentNotification(String itemId, String itemTitle,
      String commenterName, String authorId, String itemType) async {
    await _notificationService.showCustomNotification(
      title: 'New Comment',
      body: '$commenterName commented on your $itemType: "$itemTitle"',
      data: {
        'type': '${itemType}_comment',
        'itemId': itemId,
        'commenterName': commenterName,
        'authorId': authorId,
      },
    );
  }

  Future<void> _sendRsvpNotification(String eventId, String eventTitle,
      String attendeeName, String organizerId) async {
    await _notificationService.showCustomNotification(
      title: 'New RSVP',
      body: '$attendeeName RSVPed to your event: "$eventTitle"',
      data: {
        'type': 'event_rsvp',
        'eventId': eventId,
        'attendeeName': attendeeName,
        'organizerId': organizerId,
      },
    );
  }

  // Get streams for UI
  Stream<QuerySnapshot> getPrayersStream() {
    return _firestore
        .collection('prayers')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getVideosStream() {
    return _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getEventsStream() {
    return _firestore
        .collection('events')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get specific item
  Future<Map<String, dynamic>?> getPrayer(String prayerId) async {
    final doc = await _firestore.collection('prayers').doc(prayerId).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> getVideo(String videoId) async {
    final doc = await _firestore.collection('videos').doc(videoId).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> getEvent(String eventId) async {
    final doc = await _firestore.collection('events').doc(eventId).get();
    return doc.data();
  }
}
