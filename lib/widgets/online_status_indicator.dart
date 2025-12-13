import 'package:flutter/material.dart';
import '../services/presence_service.dart';

class OnlineStatusIndicator extends StatelessWidget {
  final String userId;
  final double size;
  final bool showBorder;

  const OnlineStatusIndicator({
    super.key,
    required this.userId,
    this.size = 12,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final presenceService = PresenceService();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: presenceService.getUserPresenceStream(userId),
      builder: (context, snapshot) {
        final presence = snapshot.data;
        final isOnline = presence?['isOnline'] ?? false;

        if (!isOnline) return const SizedBox.shrink();

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: showBorder
                ? Border.all(
                    color: Colors.white,
                    width: 2,
                  )
                : null,
          ),
        );
      },
    );
  }
}
