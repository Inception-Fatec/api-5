import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_colors.dart';

// Barrel: quem importa app_theme.dart continua enxergando todos os
// tokens (AppColors, AppSpacing, AppRadius, AppTextStyles...).
export 'package:tecsys_app/core/theme/app_breakpoints.dart';
export 'package:tecsys_app/core/theme/app_button_styles.dart';
export 'package:tecsys_app/core/theme/app_card_styles.dart';
export 'package:tecsys_app/core/theme/app_colors.dart';
export 'package:tecsys_app/core/theme/app_decorations.dart';
export 'package:tecsys_app/core/theme/app_radius.dart';
export 'package:tecsys_app/core/theme/app_spacing.dart';
export 'package:tecsys_app/core/theme/app_text_styles.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
      bodyMedium:
          TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
      labelSmall: TextStyle(fontSize: 12, color: AppColors.textSecondary),
    ),
  );
}
