import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../etl_theme.dart';

/// Município com o código IBGE de 7 dígitos, que é o que o backend exige.
class Municipio {
  const Municipio({required this.codigo, required this.nome, required this.uf});

  final String codigo;
  final String nome;
  final String uf;

  String get rotulo => uf.isEmpty ? nome : '$nome - $uf';

  @override
  bool operator ==(Object other) => other is Municipio && other.codigo == codigo;

  @override
  int get hashCode => codigo.hashCode;
}

/// Lista oficial de municípios (API pública do IBGE), baixada uma vez e guardada em cache.
class MunicipioService {
  MunicipioService._();

  static const String _url = 'https://servicodados.ibge.gov.br/api/v1/localidades/municipios?orderBy=nome';
  static List<Municipio>? _cache;

  static Future<List<Municipio>> listar() async {
    final List<Municipio>? cache = _cache;
    if (cache != null) return cache;

    final http.Response r = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) throw Exception('IBGE respondeu ${r.statusCode}');

    final List<dynamic> dados = jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
    return _cache = <Municipio>[
      for (final Map e in dados.whereType<Map>())
        Municipio(codigo: e['id'].toString(), nome: e['nome'].toString(), uf: _uf(e)),
    ];
  }

  static String _uf(Map e) {
    try {
      final Object? micro = e['microrregiao'];
      if (micro is Map) return micro['mesorregiao']['UF']['sigla'].toString();
      return e['regiao-imediata']['regiao-intermediaria']['UF']['sigla'].toString();
    } catch (_) {
      return '';
    }
  }
}

/// Campo "Municípios": o usuário digita o nome, escolhe na lista e repete quantas vezes quiser.
/// Cada escolha vira um chip; [onChanged] recebe a lista atual (com os códigos IBGE).
class SeletorMunicipio extends StatefulWidget {
  const SeletorMunicipio({super.key, required this.onChanged, this.enabled = true});

  final ValueChanged<List<Municipio>> onChanged;
  final bool enabled;

  @override
  State<SeletorMunicipio> createState() => _SeletorMunicipioState();
}

class _SeletorMunicipioState extends State<SeletorMunicipio> {
  List<Municipio> _todos = const <Municipio>[];
  final List<Municipio> _escolhidos = <Municipio>[];
  TextEditingController? _campo;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final List<Municipio> lista = await MunicipioService.listar();
      if (!mounted) return;
      setState(() {
        _todos = lista;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar a lista de municípios do IBGE.';
      });
    }
  }

  void _adicionar(Municipio m) {
    if (!_escolhidos.contains(m)) {
      setState(() => _escolhidos.add(m));
      widget.onChanged(List<Municipio>.of(_escolhidos));
    }
    // Limpa o texto digitado depois que o Autocomplete preenche o campo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _campo?.clear());
  }

  void _remover(Municipio m) {
    setState(() => _escolhidos.remove(m));
    widget.onChanged(List<Municipio>.of(_escolhidos));
  }

  static const String _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüç';
  static const String _semAcento = 'aaaaaeeeeiiiiooooouuuuc';

  /// Minúsculas e sem acento, para a busca ignorar maiúsculas e acentos.
  static String _norm(String s) {
    final StringBuffer b = StringBuffer();
    for (final int r in s.toLowerCase().runes) {
      final String c = String.fromCharCode(r);
      final int i = _comAcento.indexOf(c);
      b.write(i >= 0 ? _semAcento[i] : c);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Municípios',
          style: etlText(12, weight: FontWeight.w600, color: EtlColors.slate800, lineHeight: 16),
        ),
        const SizedBox(height: 6),
        Autocomplete<Municipio>(
          displayStringForOption: (Municipio m) => m.rotulo,
          optionsBuilder: (TextEditingValue v) {
            final String q = _norm(v.text.trim());
            if (q.isEmpty) return const Iterable<Municipio>.empty();
            return _todos
                .where((Municipio m) => !_escolhidos.contains(m) && _norm(m.nome).contains(q))
                .take(30);
          },
          onSelected: _adicionar,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            _campo = controller;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: widget.enabled && !_carregando,
              style: etlText(13, color: EtlColors.slate800, lineHeight: 20),
              decoration: InputDecoration(
                isDense: true,
                hintText: _carregando
                    ? 'Carregando municípios...'
                    : (_escolhidos.isEmpty ? 'Digite o nome do município' : 'Adicionar outro município'),
                hintStyle: etlText(13, color: EtlColors.slate400, lineHeight: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.search, size: 18, color: EtlColors.slate400),
              ),
            );
          },
        ),
        if (_escolhidos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final Municipio m in _escolhidos)
                InputChip(
                  label: Text(
                    m.rotulo,
                    style: etlText(12, weight: FontWeight.w500, color: EtlColors.teal800, lineHeight: 16),
                  ),
                  backgroundColor: EtlColors.teal50,
                  side: const BorderSide(color: EtlColors.teal200),
                  deleteIconColor: EtlColors.teal700,
                  onDeleted: widget.enabled ? () => _remover(m) : null,
                ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        if (_erro != null)
          Row(
            children: [
              Expanded(child: Text(_erro!, style: etlText(12, color: EtlColors.rose700, lineHeight: 16))),
              TextButton(onPressed: _carregar, child: const Text('Tentar novamente')),
            ],
          )
        else
          Text(
            _escolhidos.isEmpty
                ? 'Somente os dados dos municípios selecionados serão gravados no banco.'
                : 'Códigos IBGE: ${_escolhidos.map((m) => m.codigo).join(', ')}',
            style: etlText(12, color: EtlColors.slate500, lineHeight: 16),
          ),
      ],
    );
  }
}