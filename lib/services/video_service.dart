import 'package:flutter/material.dart';

class VideoService extends ChangeNotifier {
  static final VideoService _instance = VideoService._internal();
  factory VideoService() => _instance;
  VideoService._internal();

  final List<Map<String, dynamic>> _videos = [];

  List<Map<String, dynamic>> get videos => List.unmodifiable(_videos);

  void addVideo(Map<String, dynamic> video) {
    final newVideo = {
      ...video,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'timestamp': _getTimeAgo(DateTime.now()),
    };
    
    _videos.insert(0, newVideo);
    notifyListeners();
  }

  void removeVideo(String videoId) {
    _videos.removeWhere((video) => video['id'] == videoId);
    notifyListeners();
  }

  void updateVideo(String videoId, Map<String, dynamic> updates) {
    final index = _videos.indexWhere((video) => video['id'] == videoId);
    if (index != -1) {
      _videos[index] = {..._videos[index], ...updates};
      notifyListeners();
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
