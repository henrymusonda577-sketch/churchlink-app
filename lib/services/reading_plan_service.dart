import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReadingPlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _readingPlansData;
  String? _currentPlanId;
  Map<String, dynamic>? _currentPlanProgress;

  Future<Map<String, dynamic>> getReadingPlans() async {
    if (_readingPlansData != null) return _readingPlansData!;

    final String jsonString =
        await rootBundle.loadString('assets/reading_plans.json');
    _readingPlansData = json.decode(jsonString);
    return _readingPlansData!;
  }

  Future<List<Map<String, dynamic>>> getAvailablePlans() async {
    final plans = await getReadingPlans();
    return List<Map<String, dynamic>>.from(plans['plans'] ?? []);
  }

  Future<Map<String, dynamic>?> getPlanDetails(String planId) async {
    final plans = await getReadingPlans();
    final planList = List<Map<String, dynamic>>.from(plans['plans'] ?? []);
    return planList.firstWhere(
      (plan) => plan['id'] == planId,
      orElse: () => {},
    );
  }

  Future<void> startReadingPlan(String planId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final planDetails = await getPlanDetails(planId);
    if (planDetails == null) return;

    _currentPlanId = planId;

    // Initialize progress
    final progress = {
      'userId': user.uid,
      'planId': planId,
      'planName': planDetails['name'],
      'startDate': FieldValue.serverTimestamp(),
      'currentDay': 1,
      'totalDays': planDetails['duration'],
      'completedDays': 0,
      'isCompleted': false,
      'dailyProgress': {},
    };

    await _firestore.collection('reading_plans').doc(user.uid).set(progress);
    _currentPlanProgress = progress;
  }

  Future<Map<String, dynamic>?> getCurrentPlanProgress() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    if (_currentPlanProgress != null) return _currentPlanProgress;

    final doc =
        await _firestore.collection('reading_plans').doc(user.uid).get();
    if (doc.exists) {
      _currentPlanProgress = doc.data();
      _currentPlanId = _currentPlanProgress!['planId'];
      return _currentPlanProgress;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getTodayReading() async {
    final progress = await getCurrentPlanProgress();
    if (progress == null || progress['isCompleted']) return null;

    final planDetails = await getPlanDetails(progress['planId']);
    if (planDetails == null) return null;

    final currentDay = progress['currentDay'];
    final readings =
        List<Map<String, dynamic>>.from(planDetails['readings'] ?? []);

    if (currentDay <= readings.length) {
      return readings[currentDay - 1];
    }
    return null;
  }

  Future<void> markDayCompleted(int day, List<String> completedReadings) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final progress = await getCurrentPlanProgress();
    if (progress == null) return;

    final dailyProgress =
        Map<String, dynamic>.from(progress['dailyProgress'] ?? {});
    dailyProgress[day.toString()] = {
      'completed': true,
      'completedReadings': completedReadings,
      'completionDate': FieldValue.serverTimestamp(),
    };

    final completedDays = progress['completedDays'] + 1;
    final isCompleted = completedDays >= progress['totalDays'];

    await _firestore.collection('reading_plans').doc(user.uid).update({
      'completedDays': completedDays,
      'currentDay':
          isCompleted ? progress['currentDay'] : progress['currentDay'] + 1,
      'isCompleted': isCompleted,
      'dailyProgress': dailyProgress,
      if (isCompleted) 'completionDate': FieldValue.serverTimestamp(),
    });

    // Update local cache
    if (_currentPlanProgress != null) {
      _currentPlanProgress!['completedDays'] = completedDays;
      _currentPlanProgress!['currentDay'] =
          isCompleted ? progress['currentDay'] : progress['currentDay'] + 1;
      _currentPlanProgress!['isCompleted'] = isCompleted;
      _currentPlanProgress!['dailyProgress'] = dailyProgress;
    }
  }

  Future<void> pauseReadingPlan() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('reading_plans').doc(user.uid).update({
      'isPaused': true,
      'pausedDate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resumeReadingPlan() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('reading_plans').doc(user.uid).update({
      'isPaused': false,
      'resumedDate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resetReadingPlan() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final progress = await getCurrentPlanProgress();
    if (progress == null) return;

    await _firestore.collection('reading_plans').doc(user.uid).update({
      'currentDay': 1,
      'completedDays': 0,
      'isCompleted': false,
      'dailyProgress': {},
      'startDate': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getReadingHistory() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final querySnapshot = await _firestore
        .collection('reading_plans')
        .where('userId', isEqualTo: user.uid)
        .orderBy('startDate', descending: true)
        .get();

    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<Map<String, dynamic>> getReadingStats() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final history = await getReadingHistory();
    final currentProgress = await getCurrentPlanProgress();

    int totalPlansStarted = history.length;
    int totalPlansCompleted =
        history.where((plan) => plan['isCompleted'] == true).length;
    int currentStreak = 0;
    int longestStreak = 0;

    // Calculate streaks from current progress
    if (currentProgress != null && !currentProgress['isCompleted']) {
      final dailyProgress =
          Map<String, dynamic>.from(currentProgress['dailyProgress'] ?? {});
      final sortedDays = dailyProgress.keys.map(int.parse).toList()..sort();

      for (int day in sortedDays) {
        if (dailyProgress[day.toString()]['completed'] == true) {
          currentStreak++;
          longestStreak =
              currentStreak > longestStreak ? currentStreak : longestStreak;
        } else {
          currentStreak = 0;
        }
      }
    }

    return {
      'totalPlansStarted': totalPlansStarted,
      'totalPlansCompleted': totalPlansCompleted,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'completionRate': totalPlansStarted > 0
          ? (totalPlansCompleted / totalPlansStarted * 100).round()
          : 0,
    };
  }
}
