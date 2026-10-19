import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_colors.dart';

/// Estilos de texto padronizados. Telas e widgets usam estes estilos
/// em vez de montar `TextStyle(fontSize: ...)` na mão.
class AppTextStyles {
  AppTextStyles._();

  // Títulos
  static TextStyle pageTitle(double fontSize) => TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary);
  static const cardTitle = TextStyle(
      fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const dialogTitle =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  static const sectionLabel = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const fieldLabel = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

  // Campos de entrada
  static const input = TextStyle(fontSize: 14, color: AppColors.textPrimary);
  static const inputLarge =
      TextStyle(fontSize: 15, color: AppColors.textPrimary);

  // Corpo
  static const bodyLargeMuted =
      TextStyle(fontSize: 15, color: AppColors.textSecondary);
  static const bodyMuted =
      TextStyle(fontSize: 14, color: AppColors.textSecondary);
  static const bodySmallMuted =
      TextStyle(fontSize: 13, color: AppColors.textSecondary);
  static const bodySmallError = TextStyle(fontSize: 13, color: AppColors.error);
  static const bodyError = TextStyle(fontSize: 14, color: AppColors.error);
  static const caption =
      TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static const captionError = TextStyle(fontSize: 12, color: AppColors.error);
  static const micro = TextStyle(fontSize: 11, color: AppColors.textSecondary);
  static const chipLabel = TextStyle(fontSize: 12);

  // Contador ao lado do título da página ("10 projetos")
  static const countBadge = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

  // Cards de métrica
  static const metricLabel = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 0.3);
  static const metricValue = TextStyle(
      fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary);
  static const metricCaption =
      TextStyle(fontSize: 13, color: AppColors.primary);

  // Cards de listagem (projetos, usuários)
  static const cardCompany = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
      letterSpacing: 0.3);
  static TextStyle statusBadge(Color color) =>
      TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color);

  // Botões (a cor vem do ButtonStyle)
  static const buttonText =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
  static const buttonTextLarge =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
}
