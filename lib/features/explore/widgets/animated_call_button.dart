import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/theme/app_colors.dart';

class AnimatedCallButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;

  const AnimatedCallButton({
    super.key,
    required this.onTap,
    this.size = 42.0,
  });

  @override
  State<AnimatedCallButton> createState() => _AnimatedCallButtonState();
}

class _AnimatedCallButtonState extends State<AnimatedCallButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _wobbleController;
  late Animation<double> _pulseScaleAnimation;
  late Animation<double> _pulseOpacityAnimation;
  late Animation<double> _wobbleAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse & Ripple ring controller (Lottie-like sonar waves)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pulseScaleAnimation = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    _pulseOpacityAnimation = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    // Wobble & bounce animation
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _wobbleAnimation = Tween<double>(begin: -0.07, end: 0.07).animate(
      CurvedAnimation(parent: _wobbleController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _wobbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: s * 1.5,
        height: s * 1.5,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Outer Ripple Ring 1 (Lottie-like radar wave)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseScaleAnimation.value,
                    child: Container(
                      width: s,
                      height: s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.neonPink.withValues(alpha: _pulseOpacityAnimation.value),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonPink.withValues(alpha: _pulseOpacityAnimation.value * 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Outer Ripple Ring 2 (Staggered glow)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final delayedVal = (_pulseController.value + 0.5) % 1.0;
                  final scale = 1.0 + (delayedVal * 0.4);
                  final opacity = (1.0 - delayedVal) * 0.5;

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: s,
                      height: s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.neonPurple.withValues(alpha: opacity * 0.3),
                      ),
                    ),
                  );
                },
              ),

              // Main Glowing Button with Wobble & Camera Icon
              AnimatedBuilder(
                animation: _wobbleAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _wobbleAnimation.value * math.pi,
                    child: Transform.scale(
                      scale: 1.0 + (_wobbleAnimation.value.abs() * 0.08),
                      child: Container(
                        width: s,
                        height: s,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Colors.white,
                              Color(0xFFFFF0F5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonPink.withValues(alpha: 0.7),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 2),
                            ),
                            BoxShadow(
                              color: const Color(0xFF9C27B0).withValues(alpha: 0.4),
                              blurRadius: 18,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulse aura inside icon
                              Icon(
                                Icons.videocam_rounded,
                                color: const Color(0xFFE91E63),
                                size: s * 0.58,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
