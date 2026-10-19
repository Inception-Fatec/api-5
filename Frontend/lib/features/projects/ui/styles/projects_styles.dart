import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Medidas e estilos próprios da tela "Meus Projetos". Valores
/// avulsos ficam AQUI; os widgets só consomem. O que é comum às telas
/// de listagem (card, métricas, busca, botão, título) fica em
/// `core/theme` e `core/widgets`.
class ProjectsStyles {
  ProjectsStyles._();

  // Layout
  static const webPagePadding =
      EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg);
  static const mobilePagePadding = EdgeInsets.all(AppSpacing.lg);
  static const gridSpacing = AppSpacing.md;
  static const webTitleSize = 26.0;
  static const mobileTitleSize = 24.0;

  // Estado vazio (nenhum projeto criado ainda)
  static const emptyStatePadding = EdgeInsets.symmetric(vertical: 48);
  static const emptyStateIconSize = 48.0;
  static const emptyStateText =
      TextStyle(fontSize: 16, color: AppColors.textSecondary);

  // Estados da lista
  static const loadingPadding = EdgeInsets.symmetric(vertical: 48);
  static const messagePadding = EdgeInsets.symmetric(vertical: 32);
}
