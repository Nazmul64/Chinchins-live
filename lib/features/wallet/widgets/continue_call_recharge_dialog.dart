import 'package:flutter/material.dart';
import '../../../core/models/model_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cached_image_loader.dart';

class ContinueCallRechargeDialog extends StatelessWidget {
  final ModelProfile model;
  final VoidCallback onClose;
  final VoidCallback onGetCoins;
  final String durationText;

  const ContinueCallRechargeDialog({
    super.key,
    required this.model,
    required this.onClose,
    required this.onGetCoins,
    this.durationText = '01:19',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Main White / Soft Tint Card
          Container(
            margin: const EdgeInsets.only(top: 40),
            padding: const EdgeInsets.fromLTRB(16, 45, 16, 20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F6FA),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Host Photo + Message Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Host Portrait Photo on Left
                    Container(
                      width: 100,
                      height: 125,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5D4EC), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedImageLoader(
                          imageUrl: model.avatarUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Right Side Speech Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Girls are still eagerly waiting for your reply. Recharge and enjoy happy time with her now~',
                            style: TextStyle(
                              color: Color(0xFF4A4458),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 💎 7560 | BDT 150.00 Badge
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFFD180), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Left (Coins)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.diamond_rounded, color: AppColors.gemYellow, size: 18),
                                      SizedBox(width: 4),
                                      Text(
                                        '7560',
                                        style: TextStyle(
                                          color: Color(0xFF333333),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Spacer(),

                                // Right (BDT Price in Orange Capsule)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFFF7043), Color(0xFFF4511E)],
                                    ),
                                    borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                                  ),
                                  child: const Text(
                                    'BDT 150.00',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                const SizedBox(height: 20),

                // "Get Coins" Big Orange Button matching Screenshot
                GestureDetector(
                  onTap: onGetCoins,
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5722).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Get Coins',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),

          // Top Header Graphic: Big Shiny Diamond with Red Ribbon matching Screenshot
          Positioned(
            top: 0,
            child: SizedBox(
              width: 220,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ribbon Banner
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    width: 200,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF3D00), Color(0xFFFF6E40), Color(0xFFFF3D00)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3D00).withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),

                  // Big Center Golden Diamond
                  Positioned(
                    top: 2,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFFF8F00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gemYellow.withValues(alpha: 0.6),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.diamond_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top Right '✕' Close Button matching Screenshot
          Positioned(
            top: 48,
            right: 12,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.08),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF757575),
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
