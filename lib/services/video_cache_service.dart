import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class VideoCacheService {
  static final VideoCacheService _instance = VideoCacheService._internal();

  factory VideoCacheService() {
    return _instance;
  }

  VideoCacheService._internal();

  Future<Directory> get _cacheDir async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('\${dir.path}/video_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<File?> getCachedVideoFile(String url) async {
    final cacheDir = await _cacheDir;
    final fileName = Uri.parse(url).pathSegments.last;
    final file = File('\${cacheDir.path}/\$fileName');
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<File> downloadAndCacheVideo(String url) async {
    final cacheDir = await _cacheDir;
    final fileName = Uri.parse(url).pathSegments.last;
    final file = File('\${cacheDir.path}/\$fileName');

    if (await file.exists()) {
      return file;
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } else {
      throw Exception('Failed to download video');
    }
  }

  Future<void> clearOldCache({int maxCacheSizeMB = 500}) async {
    final cacheDir = await _cacheDir;
    final files = cacheDir.listSync().whereType<File>().toList();

    // Calculate total cache size
    int totalSize = 0;
    for (var file in files) {
      totalSize += await file.length();
    }
    totalSize = totalSize ~/ (1024 * 1024); // Convert to MB

    if (totalSize <= maxCacheSizeMB) {
      return;
    }

    // Sort files by last accessed time ascending (oldest first)
    files.sort((a, b) => a.lastAccessedSync().compareTo(b.lastAccessedSync()));

    int sizeFreed = 0;
    for (var file in files) {
      final fileSize = await file.length();
      await file.delete();
      sizeFreed += fileSize ~/ (1024 * 1024);
      if ((totalSize - sizeFreed) <= maxCacheSizeMB) {
        break;
      }
    }
  }
}
