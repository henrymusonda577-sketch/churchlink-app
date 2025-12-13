import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Badge levels configuration
  static const Map<String, Map<String, dynamic>> badgeLevels = {
    'supporter': {
      'name': 'Faithful Supporter',
      'icon': '🙏',
      'color': 0xFF4CAF50,
      'minAmount': 10.0,
      'minDonations': 1,
    },
    'giver': {
      'name': 'Generous Giver',
      'icon': '💝',
      'color': 0xFF2196F3,
      'minAmount': 50.0,
      'minDonations': 3,
    },
    'steward': {
      'name': 'Faithful Steward',
      'icon': '⭐',
      'color': 0xFFFF9800,
      'minAmount': 100.0,
      'minDonations': 5,
    },
    'champion': {
      'name': 'Kingdom Champion',
      'icon': '👑',
      'color': 0xFF9C27B0,
      'minAmount': 250.0,
      'minDonations': 10,
    },
    'blessing': {
      'name': 'Blessing Bearer',
      'icon': '✨',
      'color': 0xFFFFD700,
      'minAmount': 500.0,
      'minDonations': 15,
    },
  };

  Future<void> recordDonation(double amount) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      final data = snapshot.data() ?? {};
      
      final currentTotal = (data['totalDonations'] ?? 0.0) + amount;
      final currentCount = (data['donationCount'] ?? 0) + 1;
      final currentBadges = List<String>.from(data['badges'] ?? []);
      
      // Check for new badges
      final newBadge = _calculateBadgeLevel(currentTotal, currentCount);
      if (newBadge != null && !currentBadges.contains(newBadge)) {
        currentBadges.add(newBadge);
      }
      
      transaction.update(userDoc, {
        'totalDonations': currentTotal,
        'donationCount': currentCount,
        'badges': currentBadges,
        'lastDonation': FieldValue.serverTimestamp(),
      });
    });
  }

  String? _calculateBadgeLevel(double totalAmount, int donationCount) {
    String? highestBadge;
    
    for (final entry in badgeLevels.entries) {
      final level = entry.value;
      if (totalAmount >= level['minAmount'] && donationCount >= level['minDonations']) {
        highestBadge = entry.key;
      }
    }
    
    return highestBadge;
  }

  Future<Map<String, dynamic>> getUserBadges() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    
    return {
      'badges': List<String>.from(data['badges'] ?? []),
      'totalDonations': data['totalDonations'] ?? 0.0,
      'donationCount': data['donationCount'] ?? 0,
    };
  }

  static Map<String, dynamic>? getBadgeInfo(String badgeId) {
    return badgeLevels[badgeId];
  }
}