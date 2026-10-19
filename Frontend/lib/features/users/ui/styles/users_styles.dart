import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Medidas e estilos próprios da tela "Usuários". Segue as medidas da
/// tela de Projetos; o que é comum às duas (card, métricas, busca,
/// botão, título) fica em `core/theme` e `core/widgets`.
class UsersStyles {
  UsersStyles._();

  // Layout
  static const webPagePadding =
      EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg);
  static const mobilePagePadding = EdgeInsets.all(AppSpacing.lg);
  static const gridSpacing = AppSpacing.md;
  static const webTitleSize = 26.0;
  static const mobileTitleSize = 24.0;

  // Estados da lista
  static const loadingPadding = EdgeInsets.symmetric(vertical: 48);
  static const messagePadding = EdgeInsets.symmetric(vertical: 32);
  static const emptyStateIconSize = 48.0;
  static const emptyStateText =
      TextStyle(fontSize: 16, color: AppColors.textSecondary);

  // Filtro de perfil (ao lado da busca)
  static const filterPadding = EdgeInsets.symmetric(horizontal: AppSpacing.md);
  static const filterText = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
}
