import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF161622),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // A. Background Photo
              CachedImageLoader(
                imageUrl: model.avatarUrl,
                fit: BoxFit.cover,
              ),

              // B. Subtle Gradient Overlay for Text Readability
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x22000000),
                      Colors.transparent,
                      Color(0x55000000),
                      Color(0xE60A0A12),
                    ],
                    stops: [0.0, 0.4, 0.7, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // C. Top-Left Live / Online Badge
              Positioned(
                top: 10,
                left: 10,
                child: isLive
                    ? _buildLiveBadge()
                    : (isOnline ? _buildOnlineBadge() : const SizedBox.shrink()),
              ),

              // D. Top-Right Verified "V" Badge
              if (model.isVerified)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _buildVerifiedBadge(),
                ),

              // E. Bottom-Left Host Name & Heart / Likes Pill
              Positioned(
                left: 10,
                bottom: 10,
                right: 64, // Leave space for circular video call button
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Host Name
                    Text(
                      model.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 4),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),

                    // Pink Heart Pill (❤️ 22)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF2A6D),
                            Color(0xFFFF007F),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2A6D).withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${model.likeMeCount > 0 ? model.likeMeCount : (model.age > 0 ? model.age : 22)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // F. Bottom-Right Floating Circular Video Call Button
              Positioned(
                right: 10,
                bottom: 10,
                child: GestureDetector(
                  onTap: widget.onVideoCallTap,
                  child: _buildFloatingVideoButton(isLive),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Live Badge with 3 animated jumping equalizer sound waves
  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
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
          const SizedBox(width: 4.5),
          const Text(
            'Live',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0x8A000000), // Semi-transparent dark glass
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
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
          const SizedBox(width: 4.5),
          const Text(
            'Online',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
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
      width: 18,
      height: 18,
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
          size: 11.5,
        ),
      ),
    );
  }

  /// Floating Circular Video Camera Button matching screenshot
  Widget _buildFloatingVideoButton(bool isLive) {
    const double buttonSize = 44.0;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final scale = isLive ? (1.0 + 0.06 * math.sin(_animController.value * math.pi * 2)) : 1.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Subtle animated glow if Live
            if (isLive)
              Container(
                width: buttonSize + 8,
                height: buttonSize + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF007F).withValues(
                    alpha: (0.35 * (1.0 - _animController.value)).clamp(0.0, 1.0),
                  ),
                ),
              ),

            // 🎥 Gradient Circular Video Button with pure white camera icon
            Transform.scale(
              scale: scale,
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF007F), // Neon Magenta / Pink
                      Color(0xFF9333EA), // Vivid Purple
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF007F).withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.videocam_rounded,
                    color: Colors.white,
                    size: 24,
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
