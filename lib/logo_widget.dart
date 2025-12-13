import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  final double size;
  final bool withAnimation;
  final bool withShadow;
  final bool withGlow;

  const LogoWidget({
    Key? key,
    this.size = 200.0,
    this.withAnimation = true,
    this.withShadow = true,
    this.withGlow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: withShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15.0,
                  spreadRadius: 2.0,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect
          if (withGlow)
            Container(
              width: size * 1.1,
              height: size * 1.1,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.transparent,
                  ],
                  stops: const [0.1, 0.8],
                ),
              ),
            ),

          // Main logo image
          ClipOval(
            child: Image.asset(
              'assets/Untitled design.png',
              width: size,
              height: size,
              errorBuilder: (context, error, stackTrace) {
                print('Error loading logo: $error');
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                  ),
                  child: Icon(
                    Icons.church,
                    size: size * 0.6,
                    color: Colors.white,
                  ),
                );
              },
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );

    // Add animation if enabled
    if (withAnimation) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: logo,
      );
    }

    return logo;
  }
}
