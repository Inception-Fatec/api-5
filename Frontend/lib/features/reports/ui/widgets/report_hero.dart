import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/report_formatters.dart';
import 'package:tecsys_app/features/reports/ui/report_texts.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_section.dart';

/// Resumo no topo do relatório: anel de cobertura, selo de leitura e os
/// três números principais. Sem tempo de cálculo (decisão do produto).
class ReportHero extends StatelessWidget {
  const ReportHero({super.key, required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final color = ReportStyles.coverageColor(summary.coveragePercentage);
    return ReportCard(
      child: Column(
        children: [
          Row(
            children: [
              CoverageRing(percentage: summary.coveragePercentage),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cobertura do estudo', style: ReportStyles.rowLabel),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      formatPercent(summary.coveragePercentage),
                      style: ReportStyles.heroValue.copyWith(color: color),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${formatInt(summary.coveredPoints)} de '
                      '${formatInt(summary.totalPoints)} pontos atendidos',
                      style: ReportStyles.rowLabel,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: AppRadius.pill),
                      child: Text(
                        coverageLabel(summary.coveragePercentage),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Stat(
                icon: Icons.cell_tower,
                label: 'Gateways',
                value: formatInt(summary.selectedGateways),
              ),
              _Stat(
                icon: Icons.check_circle_outline,
                label: 'Atendidos',
                value: formatInt(summary.coveredPoints),
                color: AppColors.success,
              ),
              _Stat(
                icon: Icons.error_outline,
                label: 'Sem cobertura',
                value: formatInt(summary.uncoveredPoints),
                color: summary.uncoveredPoints > 0 ? AppColors.error : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Column(
          children: [
            Icon(icon, size: 20, color: color ?? AppColors.primary),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: ReportStyles.statValue
                      .copyWith(color: color ?? AppColors.textPrimary)),
            ),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center, style: ReportStyles.rowLabel),
          ],
        ),
      ),
    );
  }
}

/// Anel de progresso com a % de cobertura no centro.
class CoverageRing extends StatelessWidget {
  const CoverageRing({super.key, required this.percentage});

  final double percentage;

  @override
  Widget build(BuildContext context) {
    final fraction = (percentage / 100).clamp(0.0, 1.0).toDouble();
    final color = ReportStyles.coverageColor(percentage);
    return Semantics(
      label: 'Cobertura de ${formatPercent(percentage)}',
      excludeSemantics: true,
      child: SizedBox(
        width: ReportStyles.ringSize,
        height: ReportStyles.ringSize,
        child: CustomPaint(
          painter: _RingPainter(fraction: fraction, color: color),
          child: Center(
            child: Text(formatPercentCompact(percentage),
                style: ReportStyles.ringValue),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = ReportStyles.ringStroke;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = ReportStyles.ringTrack;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    if (fraction <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.color != color;
}
