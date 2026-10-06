import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/ibge_service.dart';

class NovoProjetoResultado {
  final String nome;
  final String distCode;
  final String distribuidoraLabel;
  final List<Municipio> municipios;

  const NovoProjetoResultado({
    required this.nome,
    required this.distCode,
    required this.distribuidoraLabel,
    required this.municipios,
  });
}

/// Lista fixa porque só temos dados
/// carregados pra essas duas cidades hoje.
class NewProjectDialog extends StatefulWidget {
  const NewProjectDialog({super.key});

  static Future<NovoProjetoResultado?> mostrar(BuildContext context) {
    return showDialog<NovoProjetoResultado>(
      context: context,
      builder: (context) => const NewProjectDialog(),
    );
  }

  @override
  State<NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<NewProjectDialog> {
  final _ibge = IbgeService();
  final _nomeController = TextEditingController();

  static const _distCode = '391';
  static const _distribuidoraLabel = 'EDP São Paulo (391)';

  List<Municipio>? _cidadesDisponiveis;
  final Set<Municipio> _cidadesSelecionadas = {};
  String? _erro;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarCidades();
  }

  Future<void> _carregarCidades() async {
    try {
      final sjc = await _ibge.buscarPorNome('São José dos Campos');
      final cacapava = await _ibge.buscarPorNome('Caçapava');
      final cidades = <Municipio>[
        ...sjc.where((m) => m.uf == 'SP').take(1),
        ...cacapava.where((m) => m.uf == 'SP').take(1),
      ];
      if (!mounted) return;
      setState(() {
        _cidadesDisponiveis = cidades;
        if (cidades.isNotEmpty) _cidadesSelecionadas.add(cidades.first); // SJC pré-marcado
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar as cidades agora.';
      });
    }
  }

  void _confirmar() {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Preenche o Nome do Projeto.');
      return;
    }
    if (_cidadesSelecionadas.isEmpty) {
      setState(() => _erro = 'Escolhe ao menos uma cidade.');
      return;
    }
    Navigator.of(context).pop(NovoProjetoResultado(
      nome: nome,
      distCode: _distCode,
      distribuidoraLabel: _distribuidoraLabel,
      municipios: _cidadesSelecionadas.toList(),
    ));
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.of(context).size.width;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: larguraTela < 480 ? larguraTela * 0.92 : 420,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Novo Projeto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Nome do Projeto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _nomeController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'ex: Cobertura RF - Zona Leste SJC',
                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Empresa / Distribuidora', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(10)),
                child: const Text(_distribuidoraLabel, style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Cidade(s)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (_carregando)
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator()))
              else if (_cidadesDisponiveis == null || _cidadesDisponiveis!.isEmpty)
                const Text('Nenhuma cidade com dado disponível.', style: TextStyle(fontSize: 13, color: Colors.redAccent))
              else
                Column(
                  children: _cidadesDisponiveis!
                      .map((m) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: _cidadesSelecionadas.contains(m),
                            title: Text(m.rotulo),
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _cidadesSelecionadas.add(m);
                              } else {
                                _cidadesSelecionadas.remove(m);
                              }
                            }),
                          ))
                      .toList(),
                ),
              if (_erro != null) ...[
                const SizedBox(height: 4),
                Text(_erro!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _carregando ? null : _confirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Buscar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}