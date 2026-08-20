import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Gradient gradient;
  final IconData? icon;
  final double? width;
  final double height;
  final double borderRadius;
  final double fontSize;
  final Widget? customChild;

  const GradientButton({
    super.key,
    this.text = '',
    this.onTap,
    this.gradient = AppColors.primaryGradient,
    this.icon,
    this.width,
    this.height = 44,
    this.borderRadius = 22,
    this.fontSize = 14,
    this.customChild,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: customChild ??
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: fontSize + 4),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}
