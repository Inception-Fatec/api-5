import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/state/bairro_suggestions_controller.dart';
import 'package:tecsys_app/features/map/ui/styles/filters_styles.dart';
import 'package:tecsys_app/features/map/ui/widgets/filters/filter_add_button.dart';
import 'package:tecsys_app/features/map/ui/widgets/filters/filter_value_chips.dart';

/// Filtro de bairro: campo com sugestões dos nomes reais do banco (nas
/// cidades marcadas) e os bairros já escolhidos como chips.
class BairroAutocompleteField extends StatefulWidget {
  final List<String> munCodes;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  const BairroAutocompleteField({
    super.key,
    required this.munCodes,
    required this.values,
    required this.onChanged,
  });

  @override
  State<BairroAutocompleteField> createState() =>
      _BairroAutocompleteFieldState();
}

class _BairroAutocompleteFieldState extends State<BairroAutocompleteField> {
  final _textController = TextEditingController();
  late final BairroSuggestionsController _suggestions;

  @override
  void initState() {
    super.initState();
    _suggestions = BairroSuggestionsController(munCodes: () => widget.munCodes);
  }

  void _adicionar(String bairro) {
    if (bairro.trim().isEmpty || widget.values.contains(bairro)) return;
    widget.onChanged([...widget.values, bairro]);
    _textController.clear();
    _suggestions.limpar();
  }

  void _remover(String valor) =>
      widget.onChanged(widget.values.where((e) => e != valor).toList());

  @override
  void dispose() {
    _suggestions.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Nome do Bairro', style: FiltersStyles.panelTitle),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _suggestions,
                builder: (context, _) => TextField(
                  controller: _textController,
                  onChanged: _suggestions.aoDigitar,
                  onSubmitted: _adicionar,
                  style: AppTextStyles.input,
                  decoration: AppDecorations.filledInput(
                    hint: 'ex: Jardim Aquarius',
                    hintStyle: AppTextStyles.bodyMuted,
                    contentPadding: FiltersStyles.inputPaddingSmall,
                    borderRadius: AppRadius.sm,
                    suffixIcon: _suggestions.buscando
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: FiltersStyles.searchSpinnerSize,
                              height: FiltersStyles.searchSpinnerSize,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilterAddButton(
              onTap: () => _adicionar(_textController.text),
              size: FiltersStyles.addButtonSizeSmall,
              radius: AppRadius.sm,
            ),
          ],
        ),
        ListenableBuilder(
          listenable: _suggestions,
          builder: (context, _) {
            if (_suggestions.sugestoes.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: FiltersStyles.suggestionsMargin,
              constraints: const BoxConstraints(
                  maxHeight: FiltersStyles.suggestionsMaxHeight),
              decoration: FiltersStyles.suggestionsDecoration,
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: _suggestions.sugestoes
                    .map((b) => ListTile(
                          dense: true,
                          title: Text(b, style: FiltersStyles.suggestionText),
                          onTap: () => _adicionar(b),
                        ))
                    .toList(),
              ),
            );
          },
        ),
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          FilterValueChips(values: widget.values, onRemove: _remover),
        ],
      ],
    );
  }
}
