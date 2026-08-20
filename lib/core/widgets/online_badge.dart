import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class OnlineBadge extends StatefulWidget {
  final bool showText;
  final double size;

  const OnlineBadge({
    super.key,
    this.showText = true,
    this.size = 8,
  });

  @override
  State<OnlineBadge> createState() => _OnlineBadgeState();
}

class _OnlineBadgeState extends State<OnlineBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showText) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: widget.size * 1.5,
            height: widget.size * 1.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.onlineGreen.withValues(alpha: _animation.value * 0.4),
            ),
            child: Center(
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.onlineGreen,
                ),
              ),
            ),
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.onlineGreen,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.onlineGreen.withValues(alpha: _animation.value * 0.8),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          const Text(
            'Online',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
