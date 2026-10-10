import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/metric_card.dart';

/// Linha com as duas métricas: total de projetos e calculados.
class ProjectsMetrics extends StatelessWidget {
  final int total;
  final int calculados;

  const ProjectsMetrics(
      {super.key, required this.total, required this.calculados});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MetricCard(
            label: 'TOTAL',
            icon: Icons.folder_copy_outlined,
            value: '$total',
            caption: total == 1 ? 'projeto' : 'projetos',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MetricCard(
            label: 'CALCULADOS',
            icon: Icons.check_circle_outline,
            value: '$calculados',
            caption: 'concluídos',
          ),
        ),
      ],
    );
  }
}
