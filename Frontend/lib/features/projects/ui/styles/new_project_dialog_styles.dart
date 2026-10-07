import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Medidas e estilos do popup "Novo Projeto". Valores avulsos ficam
/// AQUI; os widgets só consomem.
class NewProjectDialogStyles {
  NewProjectDialogStyles._();

  static const width = 420.0;
  static const narrowScreenBreakpoint = 480.0;
  static const narrowScreenWidthFactor = 0.92;

  static const padding = EdgeInsets.all(AppSpacing.lg);
  static const title = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);

  static const fieldPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 12);
  static const readonlyFieldDecoration =
      BoxDecoration(color: AppColors.inputFill, borderRadius: AppRadius.sm);

  static const loadingPadding = EdgeInsets.symmetric(vertical: 12);
  static const submitHeight = 48.0;

  /// Largura do popup: quase a tela inteira em telas estreitas.
  static double widthFor(double screenWidth) =>
      screenWidth < narrowScreenBreakpoint
          ? screenWidth * narrowScreenWidthFactor
          : width;
}
