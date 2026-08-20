import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class VerifiedBadge extends StatelessWidget {
  final double size;

  const VerifiedBadge({
    super.key,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.verifiedBlue,
      ),
      child: Center(
        child: Icon(
          Icons.check,
          color: Colors.white,
          size: size * 0.75,
        ),
      ),
    );
  }
}
