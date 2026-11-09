import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/metric_card.dart';

/// Linha com as três métricas: total, administradores e usuários.
class UsersMetrics extends StatelessWidget {
  final int total;
  final int admins;
  final int users;

  const UsersMetrics({
    super.key,
    required this.total,
    required this.admins,
    required this.users,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MetricCard(
            label: 'TOTAL',
            icon: Icons.people_outline,
            value: '$total',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MetricCard(
            label: 'ADMINS',
            icon: Icons.admin_panel_settings_outlined,
            value: '$admins',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MetricCard(
            label: 'USUÁRIOS',
            icon: Icons.person_outline,
            value: '$users',
          ),
        ),
      ],
    );
  }
}
