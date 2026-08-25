import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/online_badge.dart';
import '../../../core/widgets/cached_image_loader.dart';
import 'animated_call_button.dart';

class ModelGridCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.cardDark,
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
              // Portrait Background Image
              CachedImageLoader(
                imageUrl: model.avatarUrl,
                fit: BoxFit.cover,
              ),

              // Gradient Overlay (Dark bottom)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0x33000000),
                      Color(0xEE0F0E17),
                    ],
                    stops: [0.35, 0.65, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // Top Badges: Online on left, Blue Verified 'v' badge on right matching Screenshot
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Online indicator
                    if (model.isOnline)
                      const OnlineBadge(showText: true)
                    else
                      const SizedBox.shrink(),

                    // Blue Verified Checkmark (v) Icon on top right (User circled in red)
                    if (model.isVerified)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF4FC3F7),
                          border: Border.all(color: Colors.white, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0288D1).withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'v',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),

              // Extra Gems Tag if available
              if (model.hasExtraGems)
                Positioned(
                  bottom: 52,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2411).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.gemYellow.withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.diamond,
                          color: AppColors.gemYellow,
                          size: 11,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Extra Gems',
                          style: TextStyle(
                            color: AppColors.gemYellow,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom Info: Name, Age Pill & Animated Video Call Button
              Positioned(
                left: 10,
                right: 8,
                bottom: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Left Column: Name & Age Pill
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name
                          Text(
                            model.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // Age pill (e.g. pink capsule with red dot + 21) matching Screenshot
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE91E63),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFD50000),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${model.age}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right: Animated Video Call Button with Lottie-like ripple & pulse waves
                    AnimatedCallButton(
                      onTap: onVideoCallTap,
                      size: 40,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
