import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';
import '../../../core/widgets/online_badge.dart';

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
              // 1. Portrait Background Image
              CachedImageLoader(
                imageUrl: model.avatarUrl,
                fit: BoxFit.cover,
              ),

              // 2. Gradient Overlay (Dark bottom for crystal clear text readability)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Color(0x66000000),
                      Color(0xEE0B0B14),
                    ],
                    stops: [0.0, 0.45, 0.70, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // 3. Top Badges: Online on left, Blue Verified checkmark badge on right
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Online badge (🟢 Online)
                    if (model.isOnline)
                      const OnlineBadge(showText: true)
                    else
                      const SizedBox.shrink(),

                    // Blue Verified Checkmark (✓) Icon on top right
                    if (model.isVerified)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00A2FF),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00A2FF).withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),

              // 4. Bottom Info: Name & Age Pill on Left, Round Video Call Button on Right
              Positioned(
                left: 10,
                right: 8,
                bottom: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Left Column: User Name (Ellipsis) & Age Pill
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Display Name with overflow ellipsis (...)
                          Text(
                            model.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // Country / Location Red indicator & Age pill (e.g. 🔴 24)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF2A6D),
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
                                const SizedBox(width: 3.5),
                                Text(
                                  '${model.age}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Right: White Circular Video Call Button with Purple Camera Icon
                    GestureDetector(
                      onTap: onVideoCallTap,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.videocam_rounded,
                            color: Color(0xFF9C27B0),
                            size: 22,
                          ),
                        ),
                      ),
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
