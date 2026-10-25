import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_legend.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_map.dart';

/// Mapa do relatório em tela cheia (mobile). [initialFocus] abre já
/// centralizado num gateway (toque na lista de gateways).
class ReportMapScreen extends StatefulWidget {
  const ReportMapScreen({
    super.key,
    required this.report,
    required this.title,
    this.initialFocus,
  });

  final CoverageReport report;
  final String title;
  final ReportGateway? initialFocus;

  @override
  State<ReportMapScreen> createState() => _ReportMapScreenState();
}

class _ReportMapScreenState extends State<ReportMapScreen> {
  bool _showGateways = true;

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: ReportMap(
              report: report,
              initialFocus: widget.initialFocus,
              gatewayMarkers: _showGateways
                  ? GatewayMarkerMode.auto
                  : GatewayMarkerMode.hidden,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Material(
                      color: AppColors.surface,
                      elevation: 3,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Voltar ao relatório',
                        icon: const Icon(Icons.arrow_back,
                            color: AppColors.textPrimary),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Material(
                        color: AppColors.surface,
                        elevation: 3,
                        borderRadius: AppRadius.pill,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Text(widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Material(
                      color: AppColors.surface,
                      elevation: 3,
                      borderRadius: AppRadius.pill,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Gateways',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            Switch(
                              value: _showGateways,
                              onChanged: (v) =>
                                  setState(() => _showGateways = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Material(
                  color: AppColors.surface,
                  elevation: 3,
                  borderRadius: AppRadius.lg,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm + 4),
                    child: ReportLegend(rangeM: report.summary.gatewayRangeM),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
