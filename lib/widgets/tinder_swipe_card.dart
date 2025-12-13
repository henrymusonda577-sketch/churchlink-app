import 'package:flutter/material.dart';
import 'dart:math';

enum SwipeDirection { none, left, right }

class TinderSwipeCard extends StatefulWidget {
  final Widget child;
  final Function(SwipeDirection)? onSwipeComplete;
  final double swipeThreshold;

  const TinderSwipeCard({
    super.key,
    required this.child,
    this.onSwipeComplete,
    this.swipeThreshold = 100.0,
  });

  @override
  State<TinderSwipeCard> createState() => _TinderSwipeCardState();
}

class _TinderSwipeCardState extends State<TinderSwipeCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  Offset _dragOffset = Offset.zero;
  SwipeDirection _currentDirection = SwipeDirection.none;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset = Offset.zero;
      _currentDirection = SwipeDirection.none;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;

      // Determine swipe direction
      if (_dragOffset.dx.abs() > 20) {
        _currentDirection = _dragOffset.dx > 0
            ? SwipeDirection.right
            : SwipeDirection.left;
      } else {
        _currentDirection = SwipeDirection.none;
      }

      // Calculate rotation based on horizontal offset
      final rotationValue = _dragOffset.dx / MediaQuery.of(context).size.width;
      _rotationAnimation = Tween<double>(
        begin: 0.0,
        end: rotationValue * 0.3, // Max 0.3 radians rotation
      ).animate(_animationController);

      // Scale down slightly when dragging
      final scaleValue = 1.0 - (_dragOffset.dx.abs() / 500).clamp(0.0, 0.05);
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: scaleValue,
      ).animate(_animationController);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    // Check if swipe threshold is met
    if (_dragOffset.dx.abs() > widget.swipeThreshold) {
      final direction = _dragOffset.dx > 0
          ? SwipeDirection.right
          : SwipeDirection.left;

      widget.onSwipeComplete?.call(direction);

      // Animate card off screen
      _animateCardOffScreen(direction);
    } else {
      // Reset card position
      _resetCardPosition();
    }
  }

  void _animateCardOffScreen(SwipeDirection direction) {
    final screenWidth = MediaQuery.of(context).size.width;
    final endOffset = direction == SwipeDirection.right
        ? Offset(screenWidth * 1.5, _dragOffset.dy)
        : Offset(-screenWidth * 1.5, _dragOffset.dy);

    setState(() {
      _dragOffset = endOffset;
    });

    // Trigger completion callback after animation
    Future.delayed(const Duration(milliseconds: 200), () {
      widget.onSwipeComplete?.call(direction);
    });
  }

  void _resetCardPosition() {
    setState(() {
      _dragOffset = Offset.zero;
      _currentDirection = SwipeDirection.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: _rotationAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Stack(
              children: [
                widget.child,
                // Overlay text/emojis
                if (_currentDirection != SwipeDirection.none)
                  Positioned.fill(
                    child: Container(
                      alignment: _currentDirection == SwipeDirection.right
                          ? Alignment.topLeft
                          : Alignment.topRight,
                      padding: const EdgeInsets.all(20),
                      child: Transform.rotate(
                        angle: _currentDirection == SwipeDirection.right
                            ? -0.3
                            : 0.3,
                        child: Text(
                          _currentDirection == SwipeDirection.right
                              ? '❤️ LIKE'
                              : '👎 NOPE',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _currentDirection == SwipeDirection.right
                                ? Colors.green.withOpacity(0.8)
                                : Colors.red.withOpacity(0.8),
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}