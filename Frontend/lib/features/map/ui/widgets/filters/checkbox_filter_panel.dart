import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/ui/styles/filters_styles.dart';

/// Painel de filtro com uma caixa de seleção por opção (seleção
/// múltipla). Com [scrollable] a lista rola dentro do painel.
class CheckboxFilterPanel extends StatelessWidget {
  final String title;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  /// Texto mostrado para cada opção (por padrão, o próprio valor).
  final String Function(String valor)? labelOf;
  final TextStyle? optionStyle;
  final bool scrollable;

  const CheckboxFilterPanel({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.labelOf,
    this.optionStyle,
    this.scrollable = false,
  });

  void _alternar(String opcao, bool marcada) {
    final novos = List<String>.from(selected);
    if (marcada) {
      novos.add(opcao);
    } else {
      novos.remove(opcao);
    }
    onChanged(novos);
  }

  @override
  Widget build(BuildContext context) {
    final lista = Column(
      children: options
          .map((opcao) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: selected.contains(opcao),
                title: Text(labelOf?.call(opcao) ?? opcao, style: optionStyle),
                activeColor: AppColors.primary,
                onChanged: (v) => _alternar(opcao, v == true),
              ))
          .toList(),
    );

    return Padding(
      padding: FiltersStyles.panelPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: FiltersStyles.panelTitle),
          const SizedBox(height: AppSpacing.sm),
          if (scrollable)
            Flexible(child: SingleChildScrollView(child: lista))
          else
            lista,
        ],
      ),
    );
  }
}
