import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_colors.dart';
import 'package:tecsys_app/core/theme/app_radius.dart';

/// Decorações reutilizáveis (campos preenchidos, caixas de seleção,
/// cards com contorno).
class AppDecorations {
  AppDecorations._();

  /// Padding interno padrão de campos preenchidos e caixas de seleção.
  static const inputContentPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  /// Caixa de fundo cinza-azulado usada por campos de seleção e dropdowns.
  static const filledBox =
      BoxDecoration(color: AppColors.inputFill, borderRadius: AppRadius.md);

  /// Card branco com contorno fino.
  static final outlinedCard = BoxDecoration(
    border: Border.all(color: AppColors.border),
    borderRadius: AppRadius.lg,
  );

  /// Elevação (px) e duração do efeito de hover dos cards de listagem.
  static const cardHoverLift = -4.0;
  static const cardAnimation = Duration(milliseconds: 150);

  /// Card de listagem (projetos, usuários): fundo branco, contorno e
  /// sombra suave; no [hover] o contorno ganha a cor primária e a
  /// sombra aumenta.
  static BoxDecoration card({bool hover = false}) {
    return BoxDecoration(
      color: AppColors.surface,
      border: Border.all(
          color: hover ? AppColors.primaryBorderHover : AppColors.border),
      borderRadius: AppRadius.xl,
      boxShadow: [
        BoxShadow(
          color: hover ? AppColors.shadowHover : AppColors.shadowSoft,
          blurRadius: hover ? 22 : 14,
          offset: Offset(0, hover ? 10 : 6),
        ),
      ],
    );
  }

  /// `InputDecoration` de campo preenchido, sem contorno.
  static InputDecoration filledInput({
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    TextStyle? hintStyle,
    EdgeInsetsGeometry? contentPadding,
    BorderRadius borderRadius = AppRadius.md,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: hintStyle,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: contentPadding,
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(
          borderRadius: borderRadius, borderSide: BorderSide.none),
    );
  }
}
