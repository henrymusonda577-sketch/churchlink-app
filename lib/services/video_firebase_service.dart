import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class VideoFirebaseService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = Uuid();

  Future<String?> uploadVideo(
    dynamic videoFile, {
    String? userId,
    Function(double)? onProgress,
    Function(String)? onError,
    int maxRetries = 3,
  }) async {
    int retryCount = 0;
    while (retryCount <= maxRetries) {
      try {
        // Generate unique video ID to prevent duplicates
        String uniqueId = _uuid.v4();
        String filePath;
        Uint8List? fileBytes;
        String fileName =
            'video_${DateTime.now().millisecondsSinceEpoch}_$uniqueId.mp4';
        String contentType = 'video/mp4';

        // Handle both web and mobile uploads with Supabase
        if (videoFile is Uint8List) {
          fileBytes = videoFile;
        } else if (videoFile != null &&
            videoFile.toString().contains('XFile')) {
          fileBytes = await videoFile.readAsBytes();
          // Keep the generated unique fileName, don't overwrite with videoFile.name
          contentType = lookupMimeType(videoFile.name ?? 'video.mp4') ?? contentType;
        } else if (videoFile is io.File) {
          fileBytes = await videoFile.readAsBytes();
          // Keep the generated unique fileName
          contentType = lookupMimeType(videoFile.path) ?? contentType;
        } else {
          throw Exception(
              'Invalid file type for upload: ${videoFile.runtimeType}');
        }

        // Upload to Supabase Storage
        if (fileBytes != null) {
          print('DEBUG: Uploading file: $fileName, size: ${fileBytes.length}, contentType: $contentType');
          print('DEBUG: Auth session: ${_supabase.auth.currentSession}');
          await _supabase.storage
              .from('videos')
              .uploadBinary(fileName, fileBytes, fileOptions: FileOptions(contentType: contentType));
          final downloadUrl =
              _supabase.storage.from('videos').getPublicUrl(fileName);
          return downloadUrl;
        } else {
          throw Exception('File bytes are null');
        }
      } catch (e) {
        retryCount++;
        if (retryCount > maxRetries) {
          onError?.call('Upload failed after $maxRetries retries: $e');
          print('Error uploading video to Firebase Storage: $e');
          return null;
        } else {
          // Exponential backoff: wait 2^retryCount seconds
          int waitTime = 1 << retryCount; // 1, 2, 4 seconds
          onError?.call(
              'Upload failed, retrying in $waitTime seconds... ($retryCount/$maxRetries)');
          await Future.delayed(Duration(seconds: waitTime));
        }
      }
    }
    return null;
  }

  // Method to validate video before upload
  Future<Map<String, dynamic>?> validateVideo(dynamic videoFile) async {
    try {
      int fileSize = 0;
      Duration? duration;

      if (kIsWeb) {
        if (videoFile is Uint8List) {
          fileSize = videoFile.lengthInBytes;
        } else if (videoFile != null &&
            videoFile.toString().contains('XFile')) {
          fileSize = await videoFile.length();
        }
      } else {
        if (videoFile is XFile) {
          final file = io.File(videoFile.path);
          fileSize = await file.length();
        } else if (videoFile is io.File) {
          fileSize = await videoFile.length();
        } else {
          throw Exception('Unsupported file type: ${videoFile.runtimeType}');
        }
      }

      // Size limit: 100MB
      const int maxSize = 100 * 1024 * 1024; // 100MB in bytes
      if (fileSize > maxSize) {
        return {'valid': false, 'error': 'Video size exceeds 100MB limit'};
      }

      // Duration validation would require video processing library
      // For now, assume duration is within limits (25 minutes max from picker)

      return {'valid': true, 'size': fileSize};
    } catch (e) {
      return {'valid': false, 'error': 'Failed to validate video: $e'};
    }
  }
}
