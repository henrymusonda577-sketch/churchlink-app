# TODO: Update Songs Section to Use YouTube URLs with Thumbnails and Embedded Player

## Tasks
- [ ] Add youtube_player_flutter dependency to pubspec.yaml
- [ ] Run flutter pub get to install the dependency
- [ ] Update _songs data structure in content_screen.dart to include 'youtubeUrl', 'thumbnailUrl', 'title', 'artist'
- [ ] Modify _showAddSongDialog to collect YouTube URL, title, and artist name, and extract thumbnail URL from YouTube URL
- [ ] Update _buildSongsTab widget to display song thumbnail, title, and artist name in a clean, clickable layout
- [ ] Implement embedded YouTube player that plays only when song is tapped/pressed (no autoplay)
- [ ] Remove or disable audioplayers usage for songs since switching to YouTube player
- [ ] Test the updated songs tab functionality to ensure thumbnails load, player embeds correctly, and plays on tap/press

## Notes
- Ensure layout is intuitive and each song entry is clearly visible and clickable
- YouTube thumbnail URL can be extracted from video ID: https://img.youtube.com/vi/{videoId}/maxresdefault.jpg
- Use YoutubePlayer widget from youtube_player_flutter package
- Handle cases where thumbnail might not load (fallback to placeholder)
