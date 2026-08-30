import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class VideoCallPill extends StatelessWidget {
  final int pricePerMin;
  final VoidCallback? onTap;
  final bool compact;
  final bool fullWidth;
  final String label;

  const VideoCallPill({
    super.key,
    this.pricePerMin = 1800,
    this.onTap,
    this.compact = false,
    this.fullWidth = false,
    this.label = 'Video Call',
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.videoCallGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.neonPink.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.videocam_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }

    final bool hasLabel = label.trim().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: hasLabel ? 6 : 8,
        ),
        decoration: BoxDecoration(
          gradient: AppColors.videoCallGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonPink.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            if (hasLabel)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 1),
                  _buildPriceTag(),
                ],
              )
            else
              _buildPriceTag(),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceTag() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.diamond_rounded,
          color: AppColors.gemYellow,
          size: 13,
        ),
        const SizedBox(width: 3),
        Text(
          '$pricePerMin/min',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}