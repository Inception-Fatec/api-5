import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_colors.dart';
import 'package:tecsys_app/core/theme/app_radius.dart';

/// Estilos de botão padronizados.
class AppButtonStyles {
  AppButtonStyles._();

  /// Botão preenchido na cor primária. [flat] zera a elevação.
  static ButtonStyle primary({
    BorderRadius radius = AppRadius.md,
    EdgeInsetsGeometry? padding,
    bool flat = false,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      padding: padding,
      shape: RoundedRectangleBorder(borderRadius: radius),
      elevation: flat ? 0 : null,
    );
  }

  /// Botão com contorno na cor primária.
  static ButtonStyle outlinedPrimary({BorderRadius radius = AppRadius.lg}) {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.primary),
      shape: RoundedRectangleBorder(borderRadius: radius),
    );
  }
}
