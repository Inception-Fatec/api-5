import 'dart:math' as math;

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

  /// Com área selecionada, os pontos de fora dela ficam mais claros.
  /// Aplicado na cor (não com widget Opacity, que cria uma camada por
  /// marcador e trava com centenas de pontos).
  static const markerOutsideAreaOpacity = 0.65;

  // Bolhas do zoom afastado (círculo com o número de pontos)

  /// Faixas de cor pela quantidade de pontos na bolha: (a partir de,
  /// cor, rótulo da legenda). A legenda usa a mesma lista.
  static const clusterFaixas = [
    (1, Color(0xFF22C55E), 'até 9'), // verde
    (10, Color(0xFFEAB308), '10 a 99'), // amarelo
    (100, Color(0xFFF97316), '100 a 999'), // laranja
    (1000, Color(0xFFDC2626), '1 mil ou mais'), // vermelho
  ];
  static const clusterFillAlpha = 0.9;

  static Color clusterColor(int count) {
    var cor = clusterFaixas.first.$2;
    for (final (minimo, c, _) in clusterFaixas) {
      if (count >= minimo) cor = c;
    }
    return cor.withOpacity(clusterFillAlpha);
  }

  static const clusterBorderColor = Colors.white;
  static const clusterBorderWidth = 2.0;
  static const clusterMinSize = 30.0;
  static const clusterMaxSize = 62.0;
  static const clusterText = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    shadows: [Shadow(color: Color(0x66000000), blurRadius: 2)],
  );

  /// Diâmetro da bolha: cresce com o log da contagem (1 ponto = mínimo,
  /// ~100 mil = máximo), para as grandes não cobrirem o mapa.
  static double clusterSize(int count) {
    final n = count < 1 ? 1 : count;
    final t = (math.log(n) / math.ln10 / 5).clamp(0.0, 1.0);
    return clusterMinSize + (clusterMaxSize - clusterMinSize) * t;
  }

  /// Troca bolhas <-> pontos individuais (esmaece um, aparece o outro).
  static const modeFadeDuration = Duration(milliseconds: 380);

  /// Reagrupar as bolhas ao mudar o zoom: ao aproximar, as bolhas novas
  /// saem de dentro da antiga (divide); ao afastar, as antigas deslizam
  /// para a nova (junta).
  static const clusterRegroupDuration = Duration(milliseconds: 380);

  /// Acima deste tanto de bolhas na tela, troca sem animar (cada quadro
  /// da animação redesenha todas).
  static const clusterMaxAnimated = 400;

  /// Deslizar a câmera ao tocar numa bolha ou nos botões + / −.
  static const cameraAnimDuration = Duration(milliseconds: 420);

  // Tela de carregamento da visão geral (ao abrir / mudar filtros)
  static const overviewScrim = Color(0xB3FFFFFF);
  static const overviewSpinnerSize = 40.0;
  static const overviewSpinnerStroke = 3.5;
  static const overviewGap = 14.0;
  static const overviewText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

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

  // --- Sombras e bordas dos elementos flutuantes novos ----------------

  static const softShadow = [
    BoxShadow(color: Color(0x1A101828), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0D101828), blurRadius: 4, offset: Offset(0, 1)),
  ];

  // Barra de ferramentas do mapa (seleção, apagar áreas, relevo)
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

  static const selectionHintBottom = 136.0;
  static const selectionHintPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 9);
  static const selectionHintDecoration = BoxDecoration(
    color: Color(0xE6111827),
    borderRadius: BorderRadius.all(Radius.circular(999)),
  );
  static const selectionHintText = TextStyle(
      color: AppColors.onPrimary, fontSize: 13, fontWeight: FontWeight.w500);

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

  static const legendGap = 8.0;
  static const legendRowGap = 3.0;
  static const legendDotSize = 9.0;
  static const legendDotGap = 6.0;
  static const legendLabel =
      TextStyle(fontSize: 11, color: AppColors.textPrimary);
}
