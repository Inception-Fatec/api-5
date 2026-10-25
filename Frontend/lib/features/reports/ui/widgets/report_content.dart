import 'package:flutter/material.dart';

import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/report_texts.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_about_section.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_efficiency_section.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_gateways_section.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_hero.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_insights_section.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_map_preview.dart';

/// Corpo do relatório, em seções que rolam juntas: resumo, mapa
/// (miniatura, só quando [onOpenMap] é informado), leitura do resultado,
/// gateways, parâmetros e dados do cálculo.
class ReportContent extends StatelessWidget {
  const ReportContent({
    super.key,
    required this.report,
    required this.onGatewayTap,
    this.onOpenMap,
  });

  final CoverageReport report;
  final ValueChanged<ReportGateway> onGatewayTap;

  /// Mostra a miniatura do mapa (layout estreito); nulo no layout
  /// largo, onde o mapa já ocupa a outra metade da tela.
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: ReportStyles.sectionGap);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ListView(
      padding: ReportStyles.pagePadding.copyWith(
          bottom: ReportStyles.pagePadding.bottom + bottomInset),
      children: [
        const SizedBox(height: 4),
        ReportHero(summary: report.summary),
        gap,
        if (onOpenMap != null) ...[
          ReportMapPreview(report: report, onOpen: onOpenMap!),
          gap,
        ],
        ReportInsightsSection(report: report),
        if (buildInsights(report).isNotEmpty) gap,
        if (report.gateways.length > 1) ...[
          ReportEfficiencySection(report: report),
          gap,
        ],
        ReportGatewaysSection(report: report, onTap: onGatewayTap),
        gap,
        ReportParamsSection(report: report),
        gap,
        ReportDataSection(summary: report.summary),
      ],
    );
  }
}
