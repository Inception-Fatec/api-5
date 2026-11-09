import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/ui/styles/filters_styles.dart';

/// Valores já adicionados a um filtro, como chips removíveis.
class FilterValueChips extends StatelessWidget {
  final List<String> values;
  final ValueChanged<String> onRemove;

  const FilterValueChips({
    super.key,
    required this.values,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: FiltersStyles.chipsSpacing,
      runSpacing: FiltersStyles.chipsSpacing,
      children: values
          .map((v) => Chip(
                label: Text(v, style: AppTextStyles.chipLabel),
                onDeleted: () => onRemove(v),
                backgroundColor: AppColors.chipBg,
                deleteIconColor: AppColors.textSecondary,
              ))
          .toList(),
    );
  }
}
