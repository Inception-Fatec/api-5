import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Título da página com um contador em formato de etiqueta ao lado
/// ("Meus Projetos  10 projetos").
class PageTitle extends StatelessWidget {
  final String title;
  final String countLabel;
  final double fontSize;

  const PageTitle({
    super.key,
    required this.title,
    required this.countLabel,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(title,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.pageTitle(fontSize)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: const BoxDecoration(
              color: AppColors.chipBg, borderRadius: AppRadius.pill),
          child: Text(countLabel, style: AppTextStyles.countBadge),
        ),
      ],
    );
  }
}
