import 'package:flutter/material.dart';

import 'package:tecsys_app/features/map/ui/styles/filters_styles.dart';
import 'package:tecsys_app/features/map/ui/widgets/filters/chip_input_field.dart';

/// Painel de filtro por códigos digitados (conjunto, subestação, CNAE).
class ChipFilterPanel extends StatelessWidget {
  final String label;
  final String hint;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  const ChipFilterPanel({
    super.key,
    required this.label,
    required this.hint,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: FiltersStyles.panelPadding,
      child: ChipInputField(
        label: label,
        hint: hint,
        values: values,
        onChanged: onChanged,
      ),
    );
  }
}
