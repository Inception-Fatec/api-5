import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/report_efficiency.dart';
import 'package:tecsys_app/features/reports/ui/report_formatters.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_gateways_section.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_section.dart';

/// "Quantos gateways valem a pena": quantos gateways cada meta de
/// cobertura exige e quanto cada faixa de gateways (de 5 em 5, 10 em 10...
/// conforme o tamanho da rede) ainda acrescenta — para mostrar até onde o
/// investimento é benéfico.
class ReportEfficiencySection extends StatelessWidget {
  const ReportEfficiencySection({super.key, required this.report});

  final CoverageReport report;

  @override
  Widget build(BuildContext context) {
    final gateways = report.gateways;
    if (gateways.length < 2) return const SizedBox.shrink();
    final milestones = coverageMilestones(gateways);
    final steps = coverageSteps(gateways);
    final low = lowGainGateways(gateways);

    return ReportSection(
      title: 'Quantos gateways valem a pena?',
      icon: Icons.trending_up,
      subtitle: 'O ganho de cada gateway novo diminui: veja até onde compensa.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (milestones.isNotEmpty) ...[
            const Text('Gateways necessários por meta',
                style: ReportStyles.rowValue),
            const SizedBox(height: AppSpacing.xs),
            for (var i = 0; i < milestones.length; i++)
              ReportKeyValueRow(
                label: 'Meta de ${formatInt(milestones[i].target.round())}%',
                value: '${formatInt(milestones[i].gatewayCount)} '
                    '${milestones[i].gatewayCount == 1 ? 'gateway' : 'gateways'}',
                caption:
                    '${formatDecimal(100 * milestones[i].shareOfGateways)}% da rede',
                showDivider: i < milestones.length - 1,
              ),
          ],
          if (steps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Text('Ganho por faixa de gateways',
                style: ReportStyles.rowValue),
            const SizedBox(height: AppSpacing.sm),
            for (final step in steps) _StepRow(step: step),
            const SizedBox(height: AppSpacing.xs),
            const _StepLegend(),
          ],
          if (low > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              decoration: const BoxDecoration(
                  color: AppColors.warningBg, borderRadius: AppRadius.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${formatInt(low)} de ${formatInt(gateways.length)} '
                      '${low == 1 ? 'gateway atende' : 'gateways atendem'} '
                      'apenas 1 ponto novo '
                      '(${formatDecimal(100 * low / gateways.length)}% da rede).',
                      style: ReportStyles.body,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final CoverageStep step;

  @override
  Widget build(BuildContext context) {
    final added = (step.gainPercent / 100).clamp(0.0, 1.0).toDouble();
    final previous =
        ((step.cumulativePercent - step.gainPercent) / 100)
            .clamp(0.0, 1.0 - added)
            .toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 1),
      child: Semantics(
        label: 'Gateways ${step.label}: cobertura acumulada '
            '${formatPercent(step.cumulativePercent)}, '
            'mais ${formatDecimal(step.gainPercent)} pontos percentuais',
        excludeSemantics: true,
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Text(step.label, style: ReportStyles.rowValue),
            ),
            Expanded(
              child: CoverageBar(
                  fractions: GatewayBarFractions(previous, added)),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 74,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatPercent(step.cumulativePercent),
                      style: ReportStyles.rowValue),
                  Text('+${formatDecimal(step.gainPercent)} p.p.',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepLegend extends StatelessWidget {
  const _StepLegend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: ReportStyles.legendDotSize,
                height: ReportStyles.legendDotSize,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(t, style: AppTextStyles.caption),
          ],
        );
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        item(ReportStyles.barNew, 'Ganho da faixa'),
        item(ReportStyles.barPrevious, 'Acumulado nas faixas anteriores'),
      ],
    );
  }
}
