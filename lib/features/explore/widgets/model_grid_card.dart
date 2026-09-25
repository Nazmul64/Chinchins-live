import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';

class ModelGridCard extends StatefulWidget {
  final ModelProfile model;
  final VoidCallback onTap;
  final VoidCallback onVideoCallTap;

  const ModelGridCard({
    super.key,
    required this.model,
    required this.onTap,
    required this.onVideoCallTap,
  });

  @override
  State<ModelGridCard> createState() => _ModelGridCardState();
}

class _ModelGridCardState extends State<ModelGridCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final bool isLive = model.isLive;
    final bool isOnline = model.isOnline;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Main Portrait Card with Bottom-Right Corner Notch Cutout
          ClipPath(
            clipper: const NotchedCardClipper(
              cornerRadius: 16.0,
              notchRadius: 26.0,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // A. Background Photo
                  CachedImageLoader(
                    imageUrl: model.avatarUrl,
                    fit: BoxFit.cover,
                  ),

                  // B. Rich Gradient Overlay
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x33000000),
                          Colors.transparent,
                          Color(0x66000000),
                          Color(0xEE0B0B14),
                        ],
                        stops: [0.0, 0.35, 0.65, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // C. Top-Left Live / Online Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: isLive
                        ? _buildLiveBadge()
                        : (isOnline ? _buildOnlineBadge() : const SizedBox.shrink()),
                  ),

                  // D. Top-Right Verified "V" Badge
                  if (model.isVerified)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildVerifiedBadge(),
                    ),

                  // E. Bottom-Left Host Name & Country Flag / Level Pill
                  Positioned(
                    left: 8,
                    bottom: 8,
                    right: 48, // Leave room for the bottom-right notched button
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Host Name
                        Text(
                          model.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 4),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3.5),

                        // Red/Pink Level / Age Pill matching screenshot
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF2A6D),
                                Color(0xFFE91E63),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF2A6D).withValues(alpha: 0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Red indicator dot
                              Container(
                                width: 5.5,
                                height: 5.5,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFD50000),
                                ),
                              ),
                              const SizedBox(width: 3.5),
                              // Level / Age number
                              Text(
                                '${model.age > 0 ? model.age : (model.level > 0 ? model.level : 20)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Floating Circular Video Camera Button nested in the bottom-right notch cutout
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: widget.onVideoCallTap,
              child: _buildFloatingVideoButton(isLive),
            ),
          ),
        ],
      ),
    );
  }

  /// Live Badge with 3 animated jumping equalizer sound waves
  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFA855F7), // Vivid Purple
            Color(0xFFEC4899), // Neon Pink/Magenta
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA855F7).withValues(alpha: 0.5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 3 Jumping Equalizer Waves
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final v = _animController.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 2.0,
                    height: 3.5 + math.sin(v * math.pi * 2) * 2.5,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 1.5),
                  Container(
                    width: 2.0,
                    height: 6.5 + math.cos(v * math.pi * 2) * 2.5,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 1.5),
                  Container(
                    width: 2.0,
                    height: 4.5 + math.sin((v + 0.5) * math.pi * 2) * 2.5,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
          const Text(
            'Live',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Online Badge with Glowing Green Dot matching screenshot
  Widget _buildOnlineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x73000000), // Semi-transparent dark glass
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glowing green status dot
          Container(
            width: 6.5,
            height: 6.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22C55E),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Online',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Verified Cyan Circle with White "V"
  Widget _buildVerifiedBadge() {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF38BDF8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
            blurRadius: 4,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: 11,
        ),
      ),
    );
  }

  /// Floating Circular Video Camera Button nested in bottom-right notch
  Widget _buildFloatingVideoButton(bool isLive) {
    const double buttonSize = 38.0;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final scale = isLive ? (1.0 + 0.08 * math.sin(_animController.value * math.pi * 2)) : 1.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Animated Pulse Rings if Live
            if (isLive)
              Container(
                width: buttonSize + 10,
                height: buttonSize + 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEC4899).withValues(
                    alpha: (0.35 * (1.0 - _animController.value)).clamp(0.0, 1.0),
                  ),
                ),
              ),

            // White Circular Button with Purple Video Camera Icon matching screenshot
            Transform.scale(
              scale: scale,
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.videocam_rounded,
                    color: Color(0xFF9333EA), // Purple Video Camera Icon
                    size: 21,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 🎨 Custom Clipper for the Smooth Bottom-Right Inward Cutout Notch
class NotchedCardClipper extends CustomClipper<Path> {
  final double cornerRadius;
  final double notchRadius;

  const NotchedCardClipper({
    this.cornerRadius = 16.0,
    this.notchRadius = 26.0,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    final nr = notchRadius;

    // Start at top-left
    path.moveTo(0, r);
    // Top-left arc
    path.quadraticBezierTo(0, 0, r, 0);
    // Top horizontal line
    path.lineTo(w - r, 0);
    // Top-right arc
    path.quadraticBezierTo(w, 0, w, r);
    // Right vertical line down to notch start
    final notchTop = h - (nr * 1.6);
    path.lineTo(w, notchTop);

    // Smooth concave inward arc for the floating video button
    path.arcToPoint(
      Offset(w - (nr * 1.6), h),
      radius: Radius.circular(nr),
      clockwise: false, // Inward curve (concave)
    );

    // Bottom horizontal line to bottom-left
    path.lineTo(r, h);
    // Bottom-left arc
    path.quadraticBezierTo(0, h, 0, h - r);
    // Left vertical line back to start
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant NotchedCardClipper oldClipper) =>
      oldClipper.cornerRadius != cornerRadius || oldClipper.notchRadius != notchRadius;
}
