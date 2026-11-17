import 'package:flutter/foundation.dart';

import 'package:tecsys_app/core/utils/distributors.dart';
import 'package:tecsys_app/features/gateway_profiles/data/gateway_profile.dart';
import 'package:tecsys_app/features/gateway_profiles/data/gateway_profile_service.dart';
import 'package:tecsys_app/features/projects/data/models/novo_projeto_resultado.dart';
import 'package:tecsys_app/features/projects/data/services/distribuidoras_service.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';

/// Estado do popup "Novo Projeto": distribuidoras e cidades com dado no
/// banco, as marcadas, o erro de validação e a montagem do resultado.
class NewProjectDialogController extends ChangeNotifier {
  NewProjectDialogController({
    IbgeService? ibgeService,
    DistribuidorasService? distribuidorasService,
    GatewayProfileService? perfisService,
  })  : _perfisService = perfisService ?? GatewayProfileService(),
        _distribuidorasService =
            distribuidorasService ?? DistribuidorasService(),
        _ibge = ibgeService ??
            IbgeService(distribuidoras: distribuidorasService);

  final DistribuidorasService _distribuidorasService;
  final GatewayProfileService _perfisService;

  List<GatewayProfile> _perfis = const [];
  int? _perfilId;
  bool _erroPerfis = false;

  /// Perfis de gateway para o seletor (#TG-79), o padrão primeiro.
  List<GatewayProfile> get perfis => _perfis;

  /// Perfil escolhido; começa no padrão. Null = o backend usa o padrão.
  int? get perfilId => _perfilId;

  /// A lista de perfis não carregou (o projeto segue com o perfil padrão).
  bool get erroPerfis => _erroPerfis;

  /// Carrega os perfis e seleciona [selecionar] (ex.: o recém-criado), o
  /// atual se ainda existir, ou o padrão.
  Future<void> carregarPerfis({int? selecionar}) async {
    try {
      final lista = await _perfisService.listar();
      if (_disposed) return;
      _perfis = lista;
      _erroPerfis = false;
      final ids = {for (final p in lista) p.id};
      final padrao = lista.where((p) => p.isDefault).map((p) => p.id).firstOrNull;
      _perfilId = ids.contains(selecionar)
          ? selecionar
          : ids.contains(_perfilId)
              ? _perfilId
              : (padrao ?? lista.firstOrNull?.id);
    } catch (_) {
      if (_disposed) return;
      _erroPerfis = true;
    }
    notifyListeners();
  }

  void escolherPerfil(int? id) {
    _perfilId = id;
    notifyListeners();
  }
  final IbgeService _ibge;
  bool _disposed = false;

  List<Distribuidora> _distribuidoras = const [];
  String? _distCode;
  List<Municipio>? _cidadesDisponiveis;
  final Set<Municipio> _cidadesSelecionadas = {};
  String? _erro;
  bool _carregando = true;
  String _busca = '';

  /// Distribuidoras com dados no banco (vazia até carregar).
  List<Distribuidora> get distribuidoras => _distribuidoras;

  /// Distribuidora escolhida; null se não há nenhuma com dados.
  String? get distCode => _distCode;

  /// Null antes de escolher a distribuidora, enquanto carrega ou se falhou.
  List<Municipio>? get cidadesDisponiveis => _cidadesDisponiveis;

  /// Texto da busca de cidades.
  String get busca => _busca;

  /// Cidades disponíveis que batem com a busca (sem diferenciar acento e
  /// maiúsculas), em ordem alfabética.
  List<Municipio> get cidadesFiltradas {
    final termo = _normalizar(_busca.trim());
    final lista = (_cidadesDisponiveis ?? const <Municipio>[])
        .where((m) => termo.isEmpty || _normalizar(m.rotulo).contains(termo))
        .toList()
      ..sort((a, b) => _normalizar(a.rotulo).compareTo(_normalizar(b.rotulo)));
    return lista;
  }

  void buscar(String texto) {
    _busca = texto;
    notifyListeners();
  }
  Set<Municipio> get cidadesSelecionadas => _cidadesSelecionadas;
  String? get erro => _erro;
  bool get carregando => _carregando;

  String get distribuidoraLabel =>
      _distCode == null ? '' : rotuloDistribuidora(_distCode!);

  /// Carrega as distribuidoras com dados. Nenhuma vem escolhida (#TG-147):
  /// as cidades aparecem depois que o usuário escolhe a distribuidora.
  Future<void> carregar() async {
    carregarPerfis();
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
    } catch (_) {
      if (_disposed) return;
      _erro = 'Não foi possível carregar as distribuidoras agora.';
    }
    _carregando = false;
    notifyListeners();
  }

  /// Troca a distribuidora: desmarca as cidades e carrega as dela.
  Future<void> escolherDistribuidora(String codigo) async {
    if (codigo == _distCode) return;
    _distCode = codigo;
    _cidadesDisponiveis = null;
    _cidadesSelecionadas.clear();
    _busca = '';
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
      _erro = _distribuidoras.isEmpty
          ? 'Nenhuma distribuidora com dados para criar o projeto.'
          : 'Escolhe a distribuidora.';
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
      gatewayProfileId: _perfilId,
    );
  }

  static const String _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüç';
  static const String _semAcento = 'aaaaaeeeeiiiiooooouuuuc';

  static String _normalizar(String s) {
    final b = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      final c = String.fromCharCode(r);
      final i = _comAcento.indexOf(c);
      b.write(i >= 0 ? _semAcento[i] : c);
    }
    return b.toString();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
