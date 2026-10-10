import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Medidas e estilos da barra de filtros do mapa e dos painéis que
/// ela abre. Valores avulsos ficam AQUI; os widgets só consomem.
class FiltersStyles {
  FiltersStyles._();

  // Barra
  static const barMargin = EdgeInsets.all(AppSpacing.sm);
  static const barPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 8);
  static const barDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppRadius.lg,
    boxShadow: [
      BoxShadow(
          color: AppColors.shadowMap, blurRadius: 8, offset: Offset(0, 2)),
    ],
  );
  static const gap = 6.0;
  static const rowGap = AppSpacing.sm;

  // Chip da distribuidora
  static const distributorIconSize = 13.0;
  static const distributorText = TextStyle(fontSize: 11);

  // Painéis (conteúdo do dropdown)
  static const panelPadding = EdgeInsets.all(14);
  static const panelTitle =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
  static const panelHint = AppTextStyles.micro;
  static const optionText = TextStyle(fontSize: 13);

  // Botão que abre o dropdown
  static const buttonPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 9);
  static const buttonIconSize = 15.0;
  static const buttonArrowSize = 16.0;
  static const buttonLabelActive = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.infoBlue);
  static const buttonLabelIdle = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary);

  static BoxDecoration buttonDecoration({required bool highlighted}) {
    return BoxDecoration(
      color: highlighted ? AppColors.infoBlueBg : AppColors.surface,
      borderRadius: AppRadius.sm,
      border: Border.all(
          color: highlighted ? AppColors.infoBlue : AppColors.border),
    );
  }

  // Dropdown (overlay)
  static const overlayMargin = 12.0;
  static const overlayMinWidth = 200.0;
  static const overlayMaxWidth = 320.0;
  static const overlayMaxHeight = 420.0;
  static const overlayOffsetY = 6.0;
  static const overlayElevation = 8.0;

  // Campos de texto com botão "+"
  static const addButtonSizeLarge = 48.0;
  static const addButtonSizeSmall = 44.0;
  static const inputPaddingLarge =
      EdgeInsets.symmetric(horizontal: 16, vertical: 14);
  static const inputPaddingSmall =
      EdgeInsets.symmetric(horizontal: 14, vertical: 12);

  // Chips de valores selecionados
  static const chipsSpacing = 6.0;

  // Sugestões de bairro
  static const suggestionsMaxHeight = 160.0;
  static const suggestionsMargin = EdgeInsets.only(top: 6);
  static final suggestionsDecoration = BoxDecoration(
    border: Border.all(color: AppColors.border),
    borderRadius: AppRadius.sm,
  );
  static const suggestionText = TextStyle(fontSize: 13);
  static const searchSpinnerSize = 14.0;

  // Painel "Áreas"
  static const areasPanelPadding = EdgeInsets.fromLTRB(14, 12, 10, 12);
  static const areasHeaderTitle =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
  static const areasCountPadding =
      EdgeInsets.symmetric(horizontal: 7, vertical: 2);
  static const areasCountBgOpacity = 0.10;
  static const areasCountText = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary);
  static const areasClearText =
      TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
  static const areasEmptyBg = Color(0xFFF4F6F9);
  static const areasEmptyPadding = EdgeInsets.all(14);
  static const areasEmptyIconSize = 22.0;
  static const areasEmptyText =
      TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4);
  static const areaCardGap = 6.0;
  static const areaCardPadding = EdgeInsets.fromLTRB(10, 9, 4, 9);
  static const areaBadgeSize = 26.0;
  static const areaBadgeText = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary);
  static const areaTitle =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const areaCoords = TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const areaRemoveIconSize = 18.0;
  static const areaCardSelectedBgOpacity = 0.08;
}