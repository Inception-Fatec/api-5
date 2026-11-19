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

  /// No mapa a mancha sai com [ReportStyles.stainOpacity] e o ponto atendido
  /// é pintado por cima dela. As amostras usam a cor final de cada um, senão
  /// a mancha aparece escura na legenda e clara no mapa (e o ponto, o inverso).
  static final Color corMancha = ReportStyles.stainColor
      .withValues(alpha: ReportStyles.stainOpacity);
  static final Color corPontoAtendido =
      Color.alphaBlend(ReportStyles.coveredPointColor, corMancha);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        _Item(color: corMancha, label: legendaAreaAtendida(assumptions)),
        const _Item(color: ReportStyles.pinColor, label: 'Gateway proposto'),
        _Item(color: corPontoAtendido, label: 'Ponto atendido'),
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
