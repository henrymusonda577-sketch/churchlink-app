import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Simple test script to diagnose community posting issues
void main() async {
  print('Testing Community Posting Functionality...');

  try {
    // Initialize Firebase
    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    final storage = FirebaseStorage.instance;

    print('Firebase services initialized');

    // Check if user is authenticated
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      print('❌ No authenticated user found');
      print('Please sign in first before testing');
      return;
    }

    print('✅ User authenticated: ${currentUser.uid}');

    // Test 1: Check Firestore connection
    try {
      final testDoc =
          await firestore.collection('test_connection').doc('test').get();
      print('✅ Firestore connection successful');
    } catch (e) {
      print('❌ Firestore connection failed: $e');
      return;
    }

    // Test 2: Check if community_posts collection exists and is readable
    try {
      final postsSnapshot =
          await firestore.collection('community_posts').limit(1).get();
      print('✅ community_posts collection is accessible');
      print('   Total posts: ${postsSnapshot.docs.length}');
    } catch (e) {
      print('❌ Error accessing community_posts: $e');
      print('   This could be a Firestore security rules issue');
    }

    // Test 3: Check if prayers collection exists and is readable
    try {
      final prayersSnapshot =
          await firestore.collection('prayers').limit(1).get();
      print('✅ prayers collection is accessible');
      print('   Total prayers: ${prayersSnapshot.docs.length}');
    } catch (e) {
      print('❌ Error accessing prayers: $e');
      print('   This could be a Firestore security rules issue');
    }

    // Test 4: Check if videos collection exists and is readable
    try {
      final videosSnapshot =
          await firestore.collection('videos').limit(1).get();
      print('✅ videos collection is accessible');
      print('   Total videos: ${videosSnapshot.docs.length}');
    } catch (e) {
      print('❌ Error accessing videos: $e');
      print('   This could be a Firestore security rules issue');
    }

    // Test 5: Check Firebase Storage access
    try {
      final storageRef = storage.ref();
      // Just check if we can list files (this will fail if no permissions)
      await storageRef.listAll();
      print('✅ Firebase Storage access successful');
    } catch (e) {
      print('❌ Firebase Storage access failed: $e');
      print('   This could be a Storage security rules issue');
    }

    print('\n📋 Summary:');
    print('1. Run the app and try to post content');
    print('2. Check the console for detailed error messages');
    print('3. If you see permission errors, check Firestore security rules');
    print('4. Common issues:');
    print('   - Missing Firestore read/write permissions');
    print('   - Missing Storage upload permissions');
    print('   - Network connectivity issues');
    print('   - User not properly authenticated');
  } catch (e) {
    print('❌ Unexpected error during testing: $e');
  }
}
