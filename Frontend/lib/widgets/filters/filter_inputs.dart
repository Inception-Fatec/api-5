import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ChipInputField extends StatefulWidget {
  final String label;
  final String hint;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  const ChipInputField({super.key, required this.label, required this.hint, required this.values, required this.onChanged});

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

  void _remover(String v) => widget.onChanged(widget.values.where((e) => e != v).toList());

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
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _adicionar(),
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _adicionar,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.infoBlueBg, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add, color: AppColors.infoBlue),
              ),
            ),
          ],
        ),
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.values
                .map((v) => Chip(
                      label: Text(v, style: const TextStyle(fontSize: 12)),
                      onDeleted: () => _remover(v),
                      backgroundColor: AppColors.chipBg,
                      deleteIconColor: AppColors.textSecondary,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class MultiSelectSheetField extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  final String Function(String valor)? rotulo;

  const MultiSelectSheetField({super.key, required this.label, required this.options, required this.selected, required this.onChanged, this.rotulo});

  Future<void> _abrirSeletor(BuildContext context) async {
    final selecaoTemp = List<String>.from(selected);
    final resultado = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppSpacing.sm),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: options
                              .map((opt) => CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: selecaoTemp.contains(opt),
                                    title: Text(rotulo?.call(opt) ?? opt),
                                    activeColor: AppColors.primary,
                                    onChanged: (v) {
                                      setModalState(() {
                                        if (v == true) {
                                          selecaoTemp.add(opt);
                                        } else {
                                          selecaoTemp.remove(opt);
                                        }
                                      });
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, selecaoTemp),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (resultado != null) onChanged(resultado);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _abrirSeletor(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected.isEmpty ? label : selected.map((v) => rotulo?.call(v) ?? v).join(', '),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: selected.isEmpty ? AppColors.textSecondary : AppColors.textPrimary),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}