import 'package:cloud_firestore/cloud_firestore.dart';

class VerseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new verse post (should be called when creating a post with verse content)
  Future<void> addVersePost(
      String postId, String userId, String content) async {
    try {
      final verseData = {
        'postId': postId,
        'userId': userId,
        'content': content,
        'likes': 0,
        'timestamp': FieldValue.serverTimestamp(),
        'isVerseOfTheDay': false,
        'verseOfTheDayExpiresAt': null,
      };
      await _firestore.collection('verses').doc(postId).set(verseData);
    } catch (e) {
      print('Error adding verse post: $e');
      rethrow;
    }
  }

  // Update likes count for a verse post
  Future<void> updateVerseLikes(String postId, int likes) async {
    try {
      await _firestore.collection('verses').doc(postId).update({
        'likes': likes,
      });
    } catch (e) {
      print('Error updating verse likes: $e');
      rethrow;
    }
  }

  // Select Verse of the Day based on likes and set expiration (3 days)
  Future<void> selectVerseOfTheDay() async {
    try {
      final now = DateTime.now();
      final expiration = now.add(const Duration(days: 3));

      // Reset previous Verse of the Day flags that have expired
      final expiredVersesQuery = await _firestore
          .collection('verses')
          .where('isVerseOfTheDay', isEqualTo: true)
          .where('verseOfTheDayExpiresAt',
              isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      for (final doc in expiredVersesQuery.docs) {
        await doc.reference.update({
          'isVerseOfTheDay': false,
          'verseOfTheDayExpiresAt': null,
        });
      }

      // Find the verse with highest likes that is not currently Verse of the Day
      final topVerseQuery = await _firestore
          .collection('verses')
          .where('isVerseOfTheDay', isEqualTo: false)
          .orderBy('likes', descending: true)
          .limit(1)
          .get();

      if (topVerseQuery.docs.isNotEmpty) {
        final topVerseDoc = topVerseQuery.docs.first;
        await topVerseDoc.reference.update({
          'isVerseOfTheDay': true,
          'verseOfTheDayExpiresAt': Timestamp.fromDate(expiration),
        });
      }
    } catch (e) {
      print('Error selecting Verse of the Day: $e');
      rethrow;
    }
  }

  // Stream to get current Verse of the Day
  Stream<DocumentSnapshot?> getCurrentVerseOfTheDay() {
    final now = Timestamp.now();
    return _firestore
        .collection('verses')
        .where('isVerseOfTheDay', isEqualTo: true)
        .where('verseOfTheDayExpiresAt', isGreaterThan: now)
        .limit(1)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.isNotEmpty ? snapshot.docs.first : null);
  }
}
