import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    TextTheme baseTextTheme;
    try {
      baseTextTheme = GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme);
    } catch (_) {
      baseTextTheme = ThemeData.dark().textTheme;
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.neonPink,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonPink,
        secondary: AppColors.neonPurple,
        surface: AppColors.surfaceDark,
        surfaceContainerHighest: AppColors.cardDark,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bottomBarBg,
        selectedItemColor: Colors.white,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
    );
  }
}
