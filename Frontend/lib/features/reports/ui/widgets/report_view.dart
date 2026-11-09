import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/state/report_controller.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_content.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_legend.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_map.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_map_screen.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_status_view.dart';

/// Corpo da tela de relatório: escolhe entre os estados (loading, vazio,
/// erro...) e o relatório pronto.
///
/// Relatório pronto: no mobile, uma página de relatório que rola (resumo,
/// miniatura do mapa, gateways...) e abre o mapa em tela cheia ao tocar;
/// a partir de [AppBreakpoints.web], mapa à esquerda e relatório à direita.
class ReportView extends StatelessWidget {
  const ReportView({super.key, required this.controller, this.onRedo});

  final ReportController controller;

  /// Repassado à tela de falha ("Refazer projeto").
  final VoidCallback? onRedo;

  void _openMap(BuildContext context, CoverageReport report,
      [ReportGateway? focus]) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReportMapScreen(
        report: report,
        title: controller.project.name,
        initialFocus: focus,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final report = controller.report;
        if (controller.status != ReportStatus.ready || report == null) {
          return ReportStatusView(controller: controller, onRedo: onRedo);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= AppBreakpoints.web) {
              return Row(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child:
                              ReportMap(report: report, controller: controller),
                        ),
                        Positioned(
                          left: AppSpacing.md,
                          bottom: AppSpacing.md,
                          child: Material(
                            color: AppColors.surface,
                            elevation: 3,
                            borderRadius: AppRadius.lg,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm + 4),
                              child: ReportLegend(
                                  rangeM: report.summary.gatewayRangeM),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: ReportStyles.sidePanelWidth,
                    decoration: const BoxDecoration(
                      color: AppColors.pageBg,
                      border: Border(left: BorderSide(color: AppColors.border)),
                    ),
                    child: ReportContent(
                      report: report,
                      onGatewayTap: controller.focarGateway,
                    ),
                  ),
                ],
              );
            }

            return ReportContent(
              report: report,
              onGatewayTap: (g) => _openMap(context, report, g),
              onOpenMap: () => _openMap(context, report),
            );
          },
        );
      },
    );
  }
}
