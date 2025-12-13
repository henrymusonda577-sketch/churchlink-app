import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class GospelSongsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Curated list of public domain gospel hymns from YouTube
  static const List<Map<String, String>> _curatedGospelSongs = [
    {
      'title': 'Amazing Grace',
      'artist': 'Traditional Hymn',
      'youtubeUrl': 'https://www.youtube.com/watch?v=CDdvReNKKuk',
      'videoId': 'CDdvReNKKuk',
      'thumbnailUrl':
          'https://img.youtube.com/vi/CDdvReNKKuk/maxresdefault.jpg',
      'description': 'A beautiful rendition of the classic public domain hymn'
    },
    {
      'title': 'Holy, Holy, Holy',
      'artist': 'Traditional Hymn',
      'youtubeUrl': 'https://www.youtube.com/watch?v=8X7Bm7Ap8XE',
      'videoId': '8X7Bm7Ap8XE',
      'thumbnailUrl':
          'https://img.youtube.com/vi/8X7Bm7Ap8XE/maxresdefault.jpg',
      'description': 'Public domain hymn praising the Holy Trinity'
    },
    {
      'title': 'Great Is Thy Faithfulness',
      'artist': 'Traditional Hymn',
      'youtubeUrl': 'https://www.youtube.com/watch?v=dTK3WYhz6wI',
      'videoId': 'dTK3WYhz6wI',
      'thumbnailUrl':
          'https://img.youtube.com/vi/dTK3WYhz6wI/maxresdefault.jpg',
      'description': 'Public domain hymn celebrating God\'s faithfulness'
    },
    {
      'title': 'It Is Well With My Soul',
      'artist': 'Traditional Hymn',
      'youtubeUrl': 'https://www.youtube.com/watch?v=hnWiT7KMzFE',
      'videoId': 'hnWiT7KMzFE',
      'thumbnailUrl':
          'https://img.youtube.com/vi/hnWiT7KMzFE/maxresdefault.jpg',
      'description': 'Public domain hymn of peace and trust in God'
    },
    {
      'title': 'How Great Thou Art',
      'artist': 'Traditional Hymn',
      'youtubeUrl': 'https://www.youtube.com/watch?v=1p7wQXmbUVU',
      'videoId': '1p7wQXmbUVU',
      'thumbnailUrl':
          'https://img.youtube.com/vi/1p7wQXmbUVU/maxresdefault.jpg',
      'description': 'Public domain hymn praising God\'s greatness'
    },
    {
      'title': 'The Old Rugged Cross',
      'artist': 'Traditional Hymn',
      'youtubeUrl': 'https://www.youtube.com/watch?v=5pFt4q8x1xE',
      'videoId': '5pFt4q8x1xE',
      'thumbnailUrl':
          'https://img.youtube.com/vi/5pFt4q8x1xE/maxresdefault.jpg',
      'description': 'Public domain hymn about the crucifixion'
    },
    {
      'title': 'Blessed Assurance',
      'artist': 'Traditional Hymn',
      'youtubeUrl': 'https://www.youtube.com/watch?v=7rR2FgLp2XI',
      'videoId': '7rR2FgLp2XI',
      'thumbnailUrl':
          'https://img.youtube.com/vi/7rR2FgLp2XI/maxresdefault.jpg',
      'description': 'Public domain hymn of assurance in salvation'
    },
    {
      'title': 'When We All Get to Heaven',
      'artist': 'Traditional Hymn',
      'youtubeUrl': 'https://www.youtube.com/watch?v=8wN5q3Kq6jA',
      'videoId': '8wN5q3Kq6jA',
      'thumbnailUrl':
          'https://img.youtube.com/vi/8wN5q3Kq6jA/maxresdefault.jpg',
      'description': 'Public domain hymn about heaven'
    }
  ];

  // Get curated gospel songs
  List<Map<String, String>> getCuratedGospelSongs() {
    developer.log('GospelSongsService: Retrieving curated gospel songs. Count: ${_curatedGospelSongs.length}',
        name: 'GospelSongsService');
    return _curatedGospelSongs;
  }

  // Initialize curated songs in Supabase if they don't exist
  Future<void> initializeCuratedSongs() async {
    try {
      final collection = _supabase.from('curated_songs');

      for (final song in _curatedGospelSongs) {
        final existingSong = await collection
            .select()
            .eq('video_id', song['videoId']!)
            .maybeSingle();

        if (existingSong == null) {
          await collection.insert({
            'title': song['title'],
            'artist': song['artist'],
            'youtube_url': song['youtubeUrl'],
            'video_id': song['videoId']!,
            'thumbnail_url': song['thumbnailUrl'],
            'description': song['description'],
            'type': 'youtube',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (e) {
      print('Error initializing curated songs: $e');
    }
  }

  // Get curated songs from Supabase
  Stream<List<Map<String, dynamic>>> getCuratedSongsStream() {
    developer.log('GospelSongsService: Streaming curated songs from Supabase',
        name: 'GospelSongsService');
    return _supabase
        .from('curated_songs')
        .stream(primaryKey: ['video_id'])
        .order('created_at', ascending: false)
        .map((data) {
          developer.log('GospelSongsService: Received ${data.length} songs from stream',
              name: 'GospelSongsService');
          return data.map((item) => Map<String, dynamic>.from(item)).toList();
        });
  }
}
