import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Selo pequeno de status/perfil: texto na cor [color] sobre o fundo
/// suave [softColor].
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color softColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.softColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: softColor, borderRadius: AppRadius.xs),
      child: Text(label, style: AppTextStyles.statusBadge(color)),
    );
  }
}
