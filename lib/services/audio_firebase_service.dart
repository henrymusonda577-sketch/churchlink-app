import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

class AudioFirebaseService {
   final SupabaseClient _supabase = Supabase.instance.client;
   final Uuid _uuid = Uuid();

  Future<String?> uploadAudio(
     dynamic audioFile, {
     String? userId,
     Function(double)? onProgress,
     Function(String)? onError,
   }) async {
     try {
       String uniqueId = _uuid.v4();
       String fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}_$uniqueId.mp3';
       String contentType = 'audio/mp3';
       String filePath = 'audio/${userId ?? 'anonymous'}/$fileName';

       Uint8List fileBytes;

       if (kIsWeb) {
         if (audioFile is Uint8List) {
           fileBytes = audioFile;
         } else {
           fileBytes = await audioFile.readAsBytes();
           fileName = audioFile.name ?? fileName;
           contentType = lookupMimeType(fileName) ?? contentType;
         }
       } else {
         final file = audioFile as io.File;
         fileName = file.path.split('/').last;
         contentType = lookupMimeType(file.path) ?? contentType;
         fileBytes = await file.readAsBytes();
       }

       // Upload to Supabase Storage
       await _supabase.storage.from('audio').uploadBinary(filePath, fileBytes);

       // Get public URL
       final publicUrl = _supabase.storage.from('audio').getPublicUrl(filePath);

       // Simulate progress for compatibility
       if (onProgress != null) {
         onProgress(100.0);
       }

       return publicUrl;
     } catch (e) {
       onError?.call('Upload failed: $e');
       print('Error uploading audio: $e');
       return null;
     }
   }

  // Method to validate audio before upload
  Future<Map<String, dynamic>?> validateAudio(dynamic audioFile) async {
    try {
      int fileSize = 0;
      String? mimeType;

      if (kIsWeb) {
        if (audioFile is Uint8List) {
          fileSize = audioFile.lengthInBytes;
          mimeType = lookupMimeType('', headerBytes: audioFile);
        } else if (audioFile != null &&
            audioFile.toString().contains('XFile')) {
          fileSize = await audioFile.length();
          mimeType = lookupMimeType(audioFile.name ?? '');
        }
      } else {
        final file = audioFile as io.File;
        fileSize = await file.length();
        mimeType = lookupMimeType(file.path);
      }

      // Size limit: 50MB for audio
      const int maxSize = 50 * 1024 * 1024; // 50MB in bytes
      if (fileSize > maxSize) {
        return {'valid': false, 'error': 'Audio size exceeds 50MB limit'};
      }

      // Validate format
      final allowedTypes = [
        'audio/mp3',
        'audio/wav',
        'audio/aac',
        'audio/mpeg'
      ];
      if (mimeType == null || !allowedTypes.contains(mimeType)) {
        return {
          'valid': false,
          'error': 'Unsupported audio format. Use MP3, WAV, or AAC.'
        };
      }

      return {'valid': true, 'size': fileSize, 'mimeType': mimeType};
    } catch (e) {
      return {'valid': false, 'error': 'Failed to validate audio: $e'};
    }
  }
}
