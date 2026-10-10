import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Medidas e estilos próprios da tela do mapa (mapa, marcadores,
/// avisos, botões flutuantes e detalhe do ponto). Valores avulsos
/// ficam AQUI; os widgets só consomem.
class MapStyles {
  MapStyles._();

  // Marcadores
  static const markerSize = 14.0;

  /// Cor do marcador conforme a camada do ponto.
  static Color layerColor(String? layer) => switch (layer) {
        'ALTO' => AppColors.layerHigh,
        'MEDIO' => AppColors.layerMedium,
        'BAIXO' => AppColors.layerLow,
        'SUB' => AppColors.layerSubstation,
        _ => AppColors.primary,
      };

  static const markerOutsideAreaOpacity = 0.65;

  // Indicador de carregamento (topo do mapa)
  static const loadingTop = 12.0;
  static const loadingSize = 18.0;
  static const loadingStroke = 2.0;

  // Botões flutuantes
  static const floatingRight = 8.0;
  static const floatingBottom = 100.0;
  static const floatingPadding = EdgeInsets.all(10);
  static const floatingIconSize = 20.0;
  static const floatingElevation = 3.0;

  // Botão de voltar
  static const backButtonPadding =
      EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.sm);

  // Aviso de zoom
  static const zoomHintBottom = 90.0;
  static const zoomHintSideMargin = AppSpacing.lg;
  static const zoomHintPadding =
      EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12);
  static const zoomHintDecoration =
      BoxDecoration(color: AppColors.scrim, borderRadius: AppRadius.md);
  static const zoomHintText =
      TextStyle(color: AppColors.onPrimary, fontSize: 13);

  // Botão "Salvar Projeto"
  static const saveBarInset = AppSpacing.md;
  static const saveButtonHeight = 52.0;
  static const saveButtonElevation = 2.0;
  static const saveButtonIconSize = 20.0;
  static const saveSpinnerSize = 22.0;
  static const saveSpinnerStroke = 2.4;

  // Detalhe do ponto
  static const detailIconBoxSize = 36.0;
  static const detailIconSize = 18.0;
  static const detailTitle =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  static const detailRowLabel = AppTextStyles.bodySmallMuted;
  static const detailRowValue =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const detailRowPadding = EdgeInsets.only(bottom: 10);


  static const softShadow = [
    BoxShadow(color: Color(0x1A101828), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0D101828), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const toolbarRight = 12.0;
  static const toolbarBottom = 100.0;
  static const toolbarPadding = EdgeInsets.all(4);
  static const toolbarItemSize = 40.0;
  static const toolbarIconSize = 20.0;
  static const toolbarItemGap = 2.0;
  static const toolbarRadius = BorderRadius.all(Radius.circular(14));
  static const toolbarItemRadius = BorderRadius.all(Radius.circular(10));
  static const toolbarActiveBgOpacity = 0.10;

  static const areaFillOpacity = 0.08;
  static const areaBorderOpacity = 0.85;
  static const areaBorderWidth = 1.5;
  static const areaHighlightFillOpacity = 0.32;
  static const areaHighlightBorderWidth = 4.0;

  static Color get areaSelectedColor =>
      Color.lerp(AppColors.primary, Colors.black, 0.25)!;
  static const areaSelectedFillOpacity = 0.20;
  static const areaSelectedBorderWidth = 2.5;
  static const areaFocusPadding = EdgeInsets.fromLTRB(48, 170, 72, 170);
  static const areaFocusMaxZoom = 18.0;
  static const areaBlinkInterval = Duration(milliseconds: 200);
  static const areaBlinkToggles = 6;

  // Seleção (retângulo arrastado) e bolinhas ✕ / ✓
  static const selectionMinSize = 12.0;
  static const selectionFillOpacity = 0.08;
  static const selectionStrokeWidth = 1.5;
  static const selectionDash = 6.0;
  static const selectionDashGap = 4.0;
  static const selectionHandleSize = 8.0;
  static const selectionBubbleSize = 32.0;
  static const selectionBubbleGap = 8.0;
  static const selectionBubbleIconSize = 17.0;
  static const selectionBubbleOffset = 8.0;
  static const selectionDiscardColor = Color(0xFFE5484D);
  static const selectionConfirmColor = Color(0xFF16A34A);

  // Dica do modo seleção
  static const selectionHintBottom = 136.0;
  static const selectionHintPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 9);
  static const selectionHintDecoration = BoxDecoration(
    color: Color(0xE6111827),
    borderRadius: BorderRadius.all(Radius.circular(999)),
  );
  static const selectionHintText = TextStyle(
      color: AppColors.onPrimary, fontSize: 13, fontWeight: FontWeight.w500);

  // Painel de coordenadas (canto inferior esquerdo)
  static const coordsLeft = 12.0;
  static const coordsBottom = 84.0;
  static const coordsPadding = EdgeInsets.fromLTRB(10, 7, 12, 8);
  static const coordsRadius = BorderRadius.all(Radius.circular(10));
  static const coordsBgOpacity = 0.94;
  static const coordsLabelWidth = 22.0;
  static const coordsColumnGap = 10.0;
  static const coordsTitle = TextStyle(
    fontSize: 9.5,
    letterSpacing: 0.8,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );
  static const coordsLabel = TextStyle(
      fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary);
  static const coordsValue = TextStyle(
    fontSize: 11.5,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Legenda de cores (acima do painel de coordenadas)
  static const legendGap = 8.0;
  static const legendRowGap = 3.0;
  static const legendDotSize = 9.0;
  static const legendDotGap = 6.0;
  static const legendLabel =
      TextStyle(fontSize: 11, color: AppColors.textPrimary);
}