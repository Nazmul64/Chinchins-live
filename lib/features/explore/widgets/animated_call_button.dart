import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedCallButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLive;
  final double size;

  const AnimatedCallButton({
    super.key,
    required this.onTap,
    this.isLive = true,
    this.size = 46.0,
  });

  @override
  State<AnimatedCallButton> createState() => _AnimatedCallButtonState();
}

class _AnimatedCallButtonState extends State<AnimatedCallButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _waveOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _waveOpacity = Tween<double>(begin: 0.9, end: 0.25).animate(
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
    final s = widget.size;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SizedBox(
            width: s + 22,
            height: s + 10,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Concentric Soundwave / Broadcast Arcs on Left & Right (( ... ))
                if (widget.isLive) ...[
                  // Outer Wave Arcs
                  CustomPaint(
                    size: Size(s + 20 * _scaleAnimation.value, s),
                    painter: _BroadcastWavePainter(
                      color: const Color(0xFFFF007F).withValues(alpha: _waveOpacity.value * 0.7),
                      radius: (s / 2) + 7 * _scaleAnimation.value,
                      strokeWidth: 2.2,
                    ),
                  ),
                  // Inner Wave Arcs
                  CustomPaint(
                    size: Size(s + 12, s),
                    painter: _BroadcastWavePainter(
                      color: const Color(0xFFFF2A6D).withValues(alpha: (_waveOpacity.value + 0.3).clamp(0.0, 1.0)),
                      radius: (s / 2) + 3.5,
                      strokeWidth: 2.0,
                    ),
                  ),
                ],

                // 2. Main Circular Glowing Live Camera Capsule Button
                Transform.scale(
                  scale: widget.isLive ? _scaleAnimation.value : 1.0,
                  child: Container(
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF007F), // Vivid Neon Pink
                          Color(0xFFFF2A6D), // Hot Pink
                          Color(0xFFE91E63), // Vibrant Magenta
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF007F).withValues(alpha: 0.65),
                          blurRadius: 10 * _scaleAnimation.value,
                          spreadRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // White Video Camera Icon
                          const Icon(
                            Icons.videocam_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(height: 1),
                          // LIVE pill text
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF007F),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Custom Painter for the (( )) broadcast wave arcs around the button
class _BroadcastWavePainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;

  _BroadcastWavePainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);

    // Left Arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75, // from 135 deg
      math.pi * 0.5,  // sweep 90 deg
      false,
      paint,
    );

    // Right Arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.25, // from -45 deg
      math.pi * 0.5,   // sweep 90 deg
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BroadcastWavePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
