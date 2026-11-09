import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/field_label.dart';
import 'package:tecsys_app/features/map/ui/styles/filters_styles.dart';
import 'package:tecsys_app/features/map/ui/widgets/filters/filter_add_button.dart';
import 'package:tecsys_app/features/map/ui/widgets/filters/filter_value_chips.dart';

/// Campo de texto que acumula valores como chips (Enter ou "+").
class ChipInputField extends StatefulWidget {
  final String label;
  final String hint;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  const ChipInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.values,
    required this.onChanged,
  });

  @override
  State<ChipInputField> createState() => _ChipInputFieldState();
}

class _ChipInputFieldState extends State<ChipInputField> {
  final _controller = TextEditingController();

  void _adicionar() {
    final texto = _controller.text.trim();
    if (texto.isEmpty || widget.values.contains(texto)) return;
    widget.onChanged([...widget.values, texto]);
    _controller.clear();
  }

  void _remover(String valor) =>
      widget.onChanged(widget.values.where((e) => e != valor).toList());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(widget.label),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _adicionar(),
                style: AppTextStyles.input,
                decoration: AppDecorations.filledInput(
                  hint: widget.hint,
                  hintStyle: AppTextStyles.bodyMuted,
                  contentPadding: FiltersStyles.inputPaddingLarge,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilterAddButton(
              onTap: _adicionar,
              size: FiltersStyles.addButtonSizeLarge,
              radius: AppRadius.md,
            ),
          ],
        ),
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          FilterValueChips(values: widget.values, onRemove: _remover),
        ],
      ],
    );
  }
}
