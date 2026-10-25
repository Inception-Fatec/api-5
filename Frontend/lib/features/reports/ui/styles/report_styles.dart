import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Valores visuais da tela de relatório (cores vêm de [AppColors]).
class ReportStyles {
  ReportStyles._();

  // --- Mapa -----------------------------------------------------------
  // Mancha: círculos opacos dentro de UM Opacity, então a sobreposição
  // não escurece e o conjunto fica uma área contínua, como na referência.
  // A mancha é o entorno dos pontos REALMENTE atendidos (já considerando
  // o relevo no motor), não um círculo do alcance do gateway.
  static const stainColor = AppColors.coverageStain;
  static const stainOpacity = 0.42;

  /// Largura mínima do "pincel" da mancha, em px (para não sumir longe).
  static const stainMinPx = 3.0;

  /// Raio visual da mancha ao redor de cada ponto atendido, em metros:
  /// fração do espaçamento típico entre pontos, limitada. É só estética
  /// (preenche as lacunas entre pontos vizinhos); não é parâmetro de RF.
  static const stainRadiusFactor = 0.5;
  static const stainRadiusMinM = 25.0;
  static const stainRadiusMaxM = 120.0;
  static double stainRadiusFor(double? spacingM) {
    if (spacingM == null) return stainRadiusMinM;
    return (spacingM * stainRadiusFactor)
        .clamp(stainRadiusMinM, stainRadiusMaxM)
        .toDouble();
  }

  /// Só a partir deste zoom os pontos atendidos aparecem como pontinhos
  /// sobre a mancha (antes, a mancha basta).
  static const coveredDotsMinZoom = 14.0;

  // Pontos desenhados direto no canvas (ver PointsLayer).
  static const coveredPointColor = AppColors.coverageStainSoft;
  static const uncoveredPointColor = AppColors.uncoveredPoint;

  /// Diâmetro do ponto em px, crescendo com o zoom (limitado).
  static double pointSize(double zoom) => (zoom - 9).clamp(1.5, 6.0).toDouble();

  // Pin do gateway
  static const pinColor = AppColors.gatewayPin;
  // Bolinhas até o zoom 13, depois pins numerados (ver GatewayMarkerStyle).
  static const markerNumberedMinZoom = 13.0;
  static const markerDotSize = 14.0;
  static const markerSmallPinSize = 30.0;
  static const pinWidth = 40.0;
  static const pinHeight = 44.0;
  static const pinIconSize = 40.0;
  static const pinNumberTop = 7.0;
  static const pinNumberStyle = TextStyle(
    color: AppColors.onPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w800,
  );

  static const mapFitPadding = EdgeInsets.all(48);
  static const previewFitPadding = EdgeInsets.all(28);
  static const captureFitPadding = EdgeInsets.all(36);
  static const focusZoom = 13.0;
  static const fallbackZoom = 11.0;

  // --- Layout ---------------------------------------------------------
  static const sidePanelWidth = 440.0;
  static const pagePadding = EdgeInsets.fromLTRB(
      AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl);
  static const sectionGap = AppSpacing.md;
  static const cardPadding = EdgeInsets.all(AppSpacing.md);
  static const previewMapHeight = 260.0;
  static const minTouchSize = 48.0;

  // --- Cobertura (faixas de leitura, escolha de UX — não é parâmetro de RF)
  static const coverageGoodFrom = 90.0;
  static const coverageMediumFrom = 60.0;

  /// Verde, laranja ou vermelho conforme a % coberta.
  static Color coverageColor(double percentage) {
    if (percentage >= coverageGoodFrom) return AppColors.success;
    if (percentage >= coverageMediumFrom) return AppColors.warning;
    return AppColors.error;
  }

  // Anel do resumo
  static const ringSize = 104.0;
  static const ringStroke = 11.0;
  static const ringTrack = AppColors.divider;

  // Barra de cobertura acumulada por gateway
  static const barHeight = 8.0;
  static const barTrack = AppColors.divider;
  static const barPrevious = AppColors.primaryBorderHover; // já coberto antes
  static const barNew = AppColors.primary; // acrescentado por este gateway

  static const badgeRadius = 15.0;

  // Lista de gateways
  static const gatewayPageSize = 10;
  static const legendDotSize = 10.0;

  // --- Textos -----------------------------------------------------------
  static const sectionTitle = TextStyle(
      fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary);
  static const heroValue = TextStyle(
      fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary);
  static const ringValue = TextStyle(
      fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary);
  static const statValue = TextStyle(
      fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary);
  static const rowLabel =
      TextStyle(fontSize: 13, color: AppColors.textSecondary);
  static const rowValue = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const body = TextStyle(
      fontSize: 14, height: 1.4, color: AppColors.textPrimary);
}
