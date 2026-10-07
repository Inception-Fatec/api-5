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
}
