import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/report_texts.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';

/// Legenda do mapa.
class ReportLegend extends StatelessWidget {
  const ReportLegend({
    super.key,
    required this.rangeM,
    this.assumptions = const ReportAssumptions(),
  });

  /// Alcance do gateway (m). Mantido para a legenda poder citá-lo; hoje a
  /// mancha não é um círculo, então não aparece no texto.
  final int rangeM;

  /// Para dizer se a mancha considerou o relevo (#TG-83).
  final ReportAssumptions assumptions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        _Item(
            color: ReportStyles.stainColor,
            label: legendaAreaAtendida(assumptions)),
        const _Item(color: ReportStyles.pinColor, label: 'Gateway proposto'),
        const _Item(
            color: ReportStyles.coveredPointColor, label: 'Ponto atendido'),
        const _Item(
            color: ReportStyles.uncoveredPointColor, label: 'Sem cobertura'),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ReportStyles.legendDotSize,
          height: ReportStyles.legendDotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
