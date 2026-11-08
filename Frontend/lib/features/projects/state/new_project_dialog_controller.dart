import 'package:flutter/foundation.dart';

import 'package:tecsys_app/core/utils/distributors.dart';
import 'package:tecsys_app/features/projects/data/models/novo_projeto_resultado.dart';
import 'package:tecsys_app/features/projects/data/services/distribuidoras_service.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';

/// Estado do popup "Novo Projeto": distribuidoras e cidades com dado no
/// banco, as marcadas, o erro de validação e a montagem do resultado.
class NewProjectDialogController extends ChangeNotifier {
  NewProjectDialogController({
    IbgeService? ibgeService,
    DistribuidorasService? distribuidorasService,
  })  : _distribuidorasService =
            distribuidorasService ?? DistribuidorasService(),
        _ibge = ibgeService ??
            IbgeService(distribuidoras: distribuidorasService);

  final DistribuidorasService _distribuidorasService;
  final IbgeService _ibge;
  bool _disposed = false;

  List<Distribuidora> _distribuidoras = const [];
  String? _distCode;
  List<Municipio>? _cidadesDisponiveis;
  final Set<Municipio> _cidadesSelecionadas = {};
  String? _erro;
  bool _carregando = true;

  /// Distribuidoras com dados no banco (vazia até carregar).
  List<Distribuidora> get distribuidoras => _distribuidoras;

  /// Distribuidora escolhida; null se não há nenhuma com dados.
  String? get distCode => _distCode;

  /// Null enquanto carrega ou se o carregamento falhou.
  List<Municipio>? get cidadesDisponiveis => _cidadesDisponiveis;
  Set<Municipio> get cidadesSelecionadas => _cidadesSelecionadas;
  String? get erro => _erro;
  bool get carregando => _carregando;

  String get distribuidoraLabel =>
      _distCode == null ? '' : rotuloDistribuidora(_distCode!);

  /// Carrega as distribuidoras com dados e as cidades da primeira (a que
  /// tem mais subestações).
  Future<void> carregar() async {
    try {
      final lista = await _distribuidorasService.listar();
      if (_disposed) return;
      _distribuidoras = lista;
      if (lista.isEmpty) {
        _erro = 'Nenhuma distribuidora com dados no banco. '
            'Carregue uma base na aba ETL & Geodados.';
        _carregando = false;
        notifyListeners();
        return;
      }
      _distCode = lista.first.codigo;
    } catch (_) {
      if (_disposed) return;
      _erro = 'Não foi possível carregar as distribuidoras agora.';
      _carregando = false;
      notifyListeners();
      return;
    }
    await _carregarCidades();
  }

  /// Troca a distribuidora: desmarca as cidades e carrega as dela.
  Future<void> escolherDistribuidora(String codigo) async {
    if (codigo == _distCode) return;
    _distCode = codigo;
    _cidadesDisponiveis = null;
    _cidadesSelecionadas.clear();
    _erro = null;
    _carregando = true;
    notifyListeners();
    await _carregarCidades();
  }

  Future<void> _carregarCidades() async {
    final codigo = _distCode!;
    try {
      final cidades = await _ibge.buscarCidadesComDados(codigo);
      // Ignora a resposta se a distribuidora mudou no meio da carga.
      if (_disposed || codigo != _distCode) return;
      _cidadesDisponiveis = cidades;
      // A primeira cidade já vem marcada.
      if (cidades.isNotEmpty) _cidadesSelecionadas.add(cidades.first);
    } catch (_) {
      if (_disposed || codigo != _distCode) return;
      _erro = 'Não foi possível carregar as cidades agora.';
    }
    _carregando = false;
    notifyListeners();
  }

  void marcarCidade(Municipio cidade, {required bool marcada}) {
    if (marcada) {
      _cidadesSelecionadas.add(cidade);
    } else {
      _cidadesSelecionadas.remove(cidade);
    }
    notifyListeners();
  }

  /// Valida e monta o resultado; devolve null (e preenche [erro]) se
  /// faltar o nome, a distribuidora ou nenhuma cidade estiver marcada.
  NovoProjetoResultado? confirmar(String nomeDigitado) {
    final nome = nomeDigitado.trim();
    if (nome.isEmpty) {
      _erro = 'Preenche o Nome do Projeto.';
      notifyListeners();
      return null;
    }
    if (_distCode == null) {
      _erro = 'Nenhuma distribuidora com dados para criar o projeto.';
      notifyListeners();
      return null;
    }
    if (_cidadesSelecionadas.isEmpty) {
      _erro = 'Escolhe ao menos uma cidade.';
      notifyListeners();
      return null;
    }
    return NovoProjetoResultado(
      nome: nome,
      distCode: _distCode!,
      distribuidoraLabel: distribuidoraLabel,
      municipios: _cidadesSelecionadas.toList(),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
