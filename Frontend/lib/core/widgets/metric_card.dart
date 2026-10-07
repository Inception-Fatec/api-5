import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Card de métrica: rótulo + ícone no topo e valor (com legenda
/// opcional) embaixo. Usado nas telas de Projetos e Usuários.
class MetricCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;

  /// Texto ao lado do valor (ex: "projetos"); omitido em cards estreitos.
  final String? caption;

  /// Cor do valor (por padrão, o texto principal).
  final Color? valueColor;

  const MetricCard({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    this.caption,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
          color: AppColors.chipBg, borderRadius: AppRadius.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.metricLabel),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(icon, size: 17, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: AppTextStyles.metricValue
                      .copyWith(color: valueColor ?? AppColors.textPrimary)),
              if (caption != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(caption!,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.metricCaption),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
