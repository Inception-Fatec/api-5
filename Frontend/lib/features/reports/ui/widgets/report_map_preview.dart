import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_legend.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_map.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_section.dart';

/// Mapa em miniatura dentro do relatório (mobile): mostra a mancha
/// inteira sem competir com a rolagem da página. Tocar abre o mapa em
/// tela cheia ([onOpen]).
class ReportMapPreview extends StatelessWidget {
  const ReportMapPreview({super.key, required this.report, required this.onOpen});

  final CoverageReport report;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ReportSection(
      title: 'Mancha de cobertura',
      icon: Icons.map_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.md,
            child: SizedBox(
              height: ReportStyles.previewMapHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ReportMap(
                      report: report,
                      interactive: false,
                      gatewayMarkers: GatewayMarkerMode.hidden,
                      fitPadding: ReportStyles.previewFitPadding,
                    ),
                  ),
                  // Toque em qualquer ponto da miniatura abre o mapa.
                  Positioned.fill(
                    child: Semantics(
                      button: true,
                      label: 'Abrir mapa em tela cheia',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onOpen,
                      ),
                    ),
                  ),
                  Positioned(
                    right: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: Material(
                      color: AppColors.surface,
                      elevation: 2,
                      borderRadius: AppRadius.pill,
                      child: InkWell(
                        borderRadius: AppRadius.pill,
                        onTap: onOpen,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_full,
                                  size: 16, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text('Expandir',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          ReportLegend(rangeM: report.summary.gatewayRangeM),
        ],
      ),
    );
  }
}
