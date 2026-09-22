import 'package:flutter/material.dart';

/// Colors per the exact spec given for the Login screen.
class AppColors {
  static const primary = Color(0xFF006A60); // Sign In button / links / icons
  static const textPrimary = Color(0xFF191A2B);
  static const textSecondary = Color(0xFF8A94A6);
  static const background = Color(0xFFFFFFFF);
  static const inputFill = Color(0xFFF0F3F9);
  static const badgeBg = Color(0xFFF0F3F9);
  static const chipBg = Color(0xFFEAF0FE); // "Deployment 01" pill
  static const pageBg = Color(0xFFF8F9FA); // map screen background
  static const infoBlue = Color(0xFF2F80ED); // layer/GPS icons, RSSI badge
  static const infoBlueBg = Color(0xFFE3EEFC);
  static const coverageFill = Color(0x402F8FE0);
  static const coverageBorder = Color(0xFF2F8FE0);
  static const success = Color(0xFF1FA971); // CONNECTED / Excellent link
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
      labelSmall: TextStyle(fontSize: 12, color: AppColors.textSecondary),
    ),
  );
}
