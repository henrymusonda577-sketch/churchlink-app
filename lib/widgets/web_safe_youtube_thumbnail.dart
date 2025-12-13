import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class WebSafeYouTubeThumbnail extends StatelessWidget {
  final String videoId;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const WebSafeYouTubeThumbnail({
    Key? key,
    required this.videoId,
    this.width = 48,
    this.height = 48,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (videoId.isEmpty) {
      return _buildFallbackWidget();
    }

    // For web, always use fallback to avoid CORS issues
    if (kIsWeb) {
      return _buildWebFallbackWidget();
    }

    // For mobile, try to load the actual thumbnail
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        color: Colors.grey[300],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: Image.network(
          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
          width: width,
          height: height,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingWidget();
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildWebFallbackWidget();
          },
        ),
      ),
    );
  }

  Widget _buildFallbackWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_video, color: Colors.grey),
    );
  }

  Widget _buildWebFallbackWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A).withOpacity(0.1),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E3A8A), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.play_circle_filled,
            color: const Color(0xFF1E3A8A),
            size: width * 0.4,
          ),
          if (height > 40)
            const Text(
              'YouTube',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: Center(
        child: SizedBox(
          width: width * 0.3,
          height: width * 0.3,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF1E3A8A),
          ),
        ),
      ),
    );
  }
}