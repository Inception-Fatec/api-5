import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/report_formatters.dart';
import 'package:tecsys_app/features/reports/ui/report_texts.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';
import 'package:tecsys_app/features/reports/ui/widgets/report_section.dart';

/// Parâmetros do estudo: texto introdutório + um item por filtro usado.
class ReportParamsSection extends StatelessWidget {
  const ReportParamsSection({super.key, required this.report});

  final CoverageReport report;

  @override
  Widget build(BuildContext context) {
    final entries = filterEntries(report.filters);
    return ReportSection(
      title: 'Parâmetros do estudo',
      icon: Icons.tune,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reportIntro(report.summary), style: ReportStyles.body),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.divider),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Os parâmetros usados neste cálculo não foram informados pelo servidor.',
                style: ReportStyles.rowLabel,
              ),
            )
          else
            for (var i = 0; i < entries.length; i++)
              ReportKeyValueRow(
                label: entries[i].label,
                value: entries[i].value,
                showDivider: i < entries.length - 1,
              ),
        ],
      ),
    );
  }
}

/// Dados do cálculo em grade de 2 colunas: rótulo pequeno em cima e o
/// valor embaixo (nada de colunas desalinhadas nem rótulo quebrado).
class ReportDataSection extends StatelessWidget {
  const ReportDataSection({super.key, required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final stats = dataStats(summary);
    return ReportSection(
      title: 'Dados do cálculo',
      icon: Icons.analytics_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = AppSpacing.sm;
          final width = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final stat in stats)
                SizedBox(width: width, child: _StatTile(stat: stat)),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final DataStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: const BoxDecoration(
          color: AppColors.inputFill, borderRadius: AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stat.label, style: ReportStyles.rowLabel),
          const SizedBox(height: AppSpacing.xs),
          Text(stat.value, style: ReportStyles.statValue),
          if (stat.caption != null)
            Text(stat.caption!, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
