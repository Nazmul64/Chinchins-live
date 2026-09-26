import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// ⚡ LivUEmptyStateCard: Pixel-perfect recreation of LivU/TikTok empty feed state
/// Instant 0ms render when feed is empty or awaiting background sync
class LivUEmptyStateCard extends StatelessWidget {
  final VoidCallback? onRefresh;
  final String title;
  final String subtitle;

  const LivUEmptyStateCard({
    super.key,
    this.onRefresh,
    this.title = 'Oops!!',
    this.subtitle = "we couldn't find more",
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF13151F),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Vector Character Graphic in Circular Backdrop
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Circular Gradient Glow
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF33384C),
                            const Color(0xFF1E212D),
                            const Color(0xFF151821),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                    ),

                    // Floating Heart Accent (Top Left)
                    Positioned(
                      top: 14,
                      left: 42,
                      child: Icon(
                        Icons.favorite_rounded,
                        color: const Color(0xFFB8C4DC).withValues(alpha: 0.75),
                        size: 16,
                      ),
                    ),

                    // Sparkle Accent (Top Right)
                    Positioned(
                      top: 36,
                      right: 22,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB8C4DC).withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    // Sparkle Accent (Middle Right)
                    Positioned(
                      bottom: 40,
                      right: 24,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB8C4DC).withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    // TV Avatar Character (Center)
                    Container(
                      width: 72,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDEE5F2),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // Left Antenna/Ear
                          Positioned(
                            top: -6,
                            left: 12,
                            child: Transform.rotate(
                              angle: -0.3,
                              child: Container(
                                width: 5,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDEE5F2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          // Right Antenna/Ear
                          Positioned(
                            top: -6,
                            right: 12,
                            child: Transform.rotate(
                              angle: 0.3,
                              child: Container(
                                width: 5,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDEE5F2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          // User Silhouette Center Screen
                          const Icon(
                            Icons.person_rounded,
                            color: Color(0xFF1E212D),
                            size: 38,
                          ),
                        ],
                      ),
                    ),

                    // Paper plane / Swoosh Accent (Bottom Right)
                    Positioned(
                      bottom: 12,
                      right: 18,
                      child: Transform.rotate(
                        angle: -0.6,
                        child: Icon(
                          Icons.navigation_rounded,
                          color: const Color(0xFFDEE5F2).withValues(alpha: 0.85),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Title: Oops!!
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 6),

              // Subtitle: we couldn't find more
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFB0B4C8).withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),

              if (onRefresh != null) ...[
                const SizedBox(height: 20),
                InkWell(
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: AppColors.neonPink,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Refresh',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
