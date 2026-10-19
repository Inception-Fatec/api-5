import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_colors.dart';
import 'package:tecsys_app/core/theme/app_spacing.dart';

/// Medidas dos cards de listagem (projetos, usuários). Os dois usam o
/// mesmo [ListCard], então têm sempre o mesmo tamanho e as mesmas fontes.
class AppCardStyles {
  AppCardStyles._();

  static const padding = EdgeInsets.all(AppSpacing.md);

  // Topo: avatar, selo e lixeira
  static const avatarRadius = 18.0;
  static const avatarIconSize = 18.0;
  static const avatarText = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.onPrimary);
  static const deleteIconSize = 18.0;

  // Faixa de destaque no topo (opcional)
  static const accentBarHeight = 4.0;

  // Espaçamentos verticais
  static const headerGap = AppSpacing.sm;
  static const subtitleGap = 2.0;
  static const dividerGap = 12.0;
  static const infoGap = 6.0;

  // Linhas de informação
  static const infoIconSize = 14.0;
}
