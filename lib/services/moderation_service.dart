import 'dart:typed_data';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ModerationService {
   final SupabaseClient _supabase = Supabase.instance.client;

  // Content categories to flag
  static const List<String> _inappropriateCategories = [
    'nudity',
    'sexual_content',
    'violence',
    'gore',
    'hate_symbols',
    'offensive_content',
    'drugs',
    'weapons'
  ];

  // Check if image contains inappropriate content
  Future<Map<String, dynamic>> moderateImage(dynamic imageFile) async {
    try {
      Uint8List imageBytes;

      if (imageFile is File) {
        imageBytes = await imageFile.readAsBytes();
      } else if (imageFile is Uint8List) {
        imageBytes = imageFile;
      } else {
        return {
          'isAppropriate': false,
          'reason': 'Invalid image format',
          'confidence': 1.0
        };
      }

      // For now, implement basic moderation logic
      // In production, you would integrate with a service like Google Cloud Vision API
      // or AWS Rekognition for proper content moderation

      final moderationResult = await _performBasicModeration(imageBytes);

      // Store moderation result in Supabase
       final user = _supabase.auth.currentUser;
       if (user != null) {
         await _storeModerationResult(user.id, moderationResult);
       }

      return moderationResult;
    } catch (e) {
      print('Error moderating image: $e');
      // Default to allowing content if moderation fails
      return {
        'isAppropriate': true,
        'reason': 'Moderation service unavailable',
        'confidence': 0.0
      };
    }
  }

  // Basic moderation logic (placeholder for production implementation)
  Future<Map<String, dynamic>> _performBasicModeration(
      Uint8List imageBytes) async {
    // Allow all profile pictures - no content moderation restrictions

    return {
      'isAppropriate': true,
      'reason': 'Profile picture accepted',
      'confidence': 1.0
    };
  }

  // Store moderation result for audit trail
   Future<void> _storeModerationResult(
       String userId, Map<String, dynamic> result) async {
     try {
       await _supabase.from('moderation_logs').insert({
         'user_id': userId,
         'type': 'profile_picture',
         'result': result,
         'created_at': DateTime.now().toIso8601String(),
       });
     } catch (e) {
       print('Error storing moderation result: $e');
     }
   }

  // Get user's moderation history
   Future<List<Map<String, dynamic>>> getUserModerationHistory(
       String userId) async {
     try {
       final response = await _supabase
           .from('moderation_logs')
           .select('*')
           .eq('user_id', userId)
           .order('created_at', ascending: false)
           .limit(10);

       return List<Map<String, dynamic>>.from(response);
     } catch (e) {
       print('Error getting moderation history: $e');
       return [];
     }
   }


  // Production-ready integration example with Google Cloud Vision
  // Uncomment and configure when you have API access
  /*
  Future<Map<String, dynamic>> _moderateWithGoogleVision(Uint8List imageBytes) async {
    const apiKey = 'YOUR_GOOGLE_CLOUD_VISION_API_KEY';
    const url = 'https://vision.googleapis.com/v1/images:annotate?key=$apiKey';

    final base64Image = base64Encode(imageBytes);

    final requestBody = {
      'requests': [
        {
          'image': {'content': base64Image},
          'features': [
            {'type': 'SAFE_SEARCH_DETECTION', 'maxResults': 1},
            {'type': 'LABEL_DETECTION', 'maxResults': 10},
          ]
        }
      ]
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return _parseGoogleVisionResponse(data);
    } else {
      throw Exception('Google Vision API error: ${response.statusCode}');
    }
  }

  Map<String, dynamic> _parseGoogleVisionResponse(Map<String, dynamic> data) {
    final responses = data['responses'] as List<dynamic>? ?? [];
    if (responses.isEmpty) {
      return {
        'isAppropriate': true,
        'reason': 'No content detected',
        'confidence': 0.0
      };
    }

    final response = responses[0] as Map<String, dynamic>;

    // Check safe search detection
    final safeSearch = response['safeSearchAnnotation'] as Map<String, dynamic>?;
    if (safeSearch != null) {
      final adult = safeSearch['adult'] as String?;
      final violence = safeSearch['violence'] as String?;
      final racy = safeSearch['racy'] as String?;

      if (adult == 'VERY_LIKELY' || adult == 'LIKELY' ||
          violence == 'VERY_LIKELY' || violence == 'LIKELY' ||
          racy == 'VERY_LIKELY') {
        return {
          'isAppropriate': false,
          'reason': 'Content flagged as inappropriate by automated moderation',
          'confidence': 0.9,
          'categories': ['inappropriate_content']
        };
      }
    }

    return {
      'isAppropriate': true,
      'reason': 'Content passed automated moderation',
      'confidence': 0.8
    };
  }
  */
}
