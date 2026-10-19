import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Linha de informação do card: ícone pequeno + texto.
class CardInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const CardInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppCardStyles.infoIconSize, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmallMuted),
        ),
      ],
    );
  }
}
