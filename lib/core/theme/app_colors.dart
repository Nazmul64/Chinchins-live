import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color backgroundDark = Color(0xFF0F0E17);
  static const Color surfaceDark = Color(0xFF161426);
  static const Color cardDark = Color(0xFF1E1B2E);
  static const Color cardDarkElevated = Color(0xFF26223B);
  static const Color cardBorder = Color(0xFF322C4D);
  static const Color bottomBarBg = Color(0xFF12101E);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF2A85), Color(0xFF9C27B0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient videoCallGradient = LinearGradient(
    colors: [Color(0xFFE91E63), Color(0xFF7B1FA2)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFFF5722), Color(0xFFFF9800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardImageOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0x60000000), Color(0xDD0F0E17)],
    stops: [0.3, 0.7, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient glassOverlay = LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x11FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Accent Colors
  static const Color neonPink = Color(0xFFFF2D75);
  static const Color neonPurple = Color(0xFFB324D7);
  static const Color vibrantOrange = Color(0xFFFF6D00);
  static const Color warmOrange = Color(0xFFFF4500);
  static const Color onlineGreen = Color(0xFF00E676);
  static const Color gemYellow = Color(0xFFFFC107);
  static const Color diamondBlue = Color(0xFF00E5FF);
  static const Color verifiedBlue = Color(0xFF2979FF);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFC4C2D6);
  static const Color textMuted = Color(0xFF7E7A99);
  static const Color textHint = Color(0xFF5A5674);

  // Status & Badges
  static const Color badgePink = Color(0xFFFF1744);
  static const Color badgeOrange = Color(0xFFFF6D00);
  static const Color badgePurple = Color(0xFF7C4DFF);
}
