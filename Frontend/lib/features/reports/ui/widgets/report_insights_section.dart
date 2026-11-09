import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/report_texts.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_section.dart';

/// "Leitura do resultado": frases calculadas só a partir dos dados.
class ReportInsightsSection extends StatelessWidget {
  const ReportInsightsSection({super.key, required this.report});

  final CoverageReport report;

  @override
  Widget build(BuildContext context) {
    final insights = buildInsights(report);
    if (insights.isEmpty) return const SizedBox.shrink();
    return ReportSection(
      title: 'Leitura do resultado',
      icon: Icons.lightbulb_outline,
      child: Column(
        children: [
          for (var i = 0; i < insights.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.sm + 2),
              child: _InsightRow(insight: insights[i]),
            ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});

  final ReportInsight insight;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (insight.kind) {
      InsightKind.success => (Icons.check_circle, AppColors.success),
      InsightKind.info => (Icons.info, AppColors.infoBlue),
      InsightKind.warning => (Icons.warning_amber_rounded, AppColors.warning),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(insight.text, style: ReportStyles.body)),
      ],
    );
  }
}
