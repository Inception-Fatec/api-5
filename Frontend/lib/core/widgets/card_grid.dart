import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Grade de cards das listas no web: 2 colunas, ou 3 a partir de
/// [AppBreakpoints.wideGrid]. Usada em Projetos, Usuários e ETL.
class CardGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const CardGrid({super.key, required this.children, this.spacing = AppSpacing.md});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= AppBreakpoints.wideGrid ? 3 : 2;
        final cardWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final c in children) SizedBox(width: cardWidth, child: c)],
        );
      },
    );
  }
}
