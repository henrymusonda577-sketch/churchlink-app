# TODO: Update Songs Section to Support Both Audio Files and YouTube URLs

## Tasks
- [ ] Modify _showAddSongDialog to offer two options: "Upload Audio File" or "Add YouTube URL"
- [ ] For YouTube option: collect URL, title, artist, extract video ID and thumbnail URL
- [ ] Update song data structure in Firestore to include 'type' (audio or youtube), 'fileUrl', 'youtubeUrl', 'thumbnailUrl', 'title', 'artist'
- [x] Update _buildSongsTab to display appropriate icon/thumbnail, title, artist
- [x] Implement play logic: audioplayers for audio, embedded YouTube player for YouTube
- [ ] Test both audio and YouTube song additions and playback

## Notes
- Keep existing audio functionality intact
- Use cached_network_image for YouTube thumbnails
- Thumbnail URL: https://img.youtube.com/vi/{videoId}/maxresdefault.jpg
- Ensure layout is intuitive for both types
