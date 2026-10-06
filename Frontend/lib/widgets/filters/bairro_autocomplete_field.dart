import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../services/points_filter_service.dart';
class BairroAutocompleteField extends StatefulWidget {
  const BairroAutocompleteField({
    super.key,
    required this.munCodes,
    required this.values,
    required this.onChanged,
  });

  final List<String> munCodes;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  State<BairroAutocompleteField> createState() => _BairroAutocompleteFieldState();
}

class _BairroAutocompleteFieldState extends State<BairroAutocompleteField> {
  final _controller = TextEditingController();
  final _service = PointsFilterService();
  Timer? _debounce;
  List<String> _sugestoes = [];
  bool _buscando = false;

  void _aoDigitar(String texto) {
    _debounce?.cancel();
    if (texto.trim().length < 2) {
      setState(() => _sugestoes = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _buscando = true);
      final resultado = await _service.buscarSugestoesBairro(munCodes: widget.munCodes, texto: texto.trim());
      if (!mounted) return;
      setState(() {
        _sugestoes = resultado;
        _buscando = false;
      });
    });
  }

  void _adicionar(String bairro) {
    if (bairro.trim().isEmpty || widget.values.contains(bairro)) return;
    widget.onChanged([...widget.values, bairro]);
    _controller.clear();
    setState(() => _sugestoes = []);
  }

  void _remover(String v) => widget.onChanged(widget.values.where((e) => e != v).toList());

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Nome do Bairro', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _aoDigitar,
                onSubmitted: _adicionar,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'ex: Jardim Aquarius',
                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  suffixIcon: _buscando
                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _adicionar(_controller.text),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.infoBlueBg, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add, color: AppColors.infoBlue),
              ),
            ),
          ],
        ),
        if (_sugestoes.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE4E8EF)), borderRadius: BorderRadius.circular(10)),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: _sugestoes
                  .map((b) => ListTile(
                        dense: true,
                        title: Text(b, style: const TextStyle(fontSize: 13)),
                        onTap: () => _adicionar(b),
                      ))
                  .toList(),
            ),
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