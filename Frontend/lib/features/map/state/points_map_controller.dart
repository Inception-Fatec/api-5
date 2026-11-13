import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:tecsys_app/core/utils/text_normalizer.dart';
import 'package:tecsys_app/features/map/data/constants/map_filter_options.dart';
import 'package:tecsys_app/features/map/data/constants/map_regions.dart';
import 'package:tecsys_app/features/map/data/models/filtros_pontos.dart';
import 'package:tecsys_app/features/map/data/models/map_point.dart';
import 'package:tecsys_app/features/map/data/models/selected_area.dart';
import 'package:tecsys_app/features/map/data/services/municipios_centro_service.dart';
import 'package:tecsys_app/features/map/data/services/points_filter_service.dart';
import 'package:tecsys_app/features/map/state/map_areas_controller.dart';
import 'package:tecsys_app/features/projects/data/models/project_version.dart';
import 'package:tecsys_app/features/projects/data/services/ibge_service.dart';
import 'package:tecsys_app/features/projects/data/services/project_service.dart';
import 'package:tecsys_app/features/projects/state/project_store.dart';

class PointsMapController extends ChangeNotifier {
  PointsMapController({
    required this.nomeProjeto,
    required this.distCode,
    required this.distribuidoraLabel,
    required List<Municipio> municipios,
    this.onFocusPoint,
    this.projetoId,
    ProjectVersion? versaoInicial,
    this.focusDebounce = const Duration(milliseconds: 600),
    PointsFilterService? pointsService,
    MunicipiosCentroService? centroService,
    IbgeService? ibgeService,
    ProjectsService? projectsService,
    ProjectsStore? store,
  })  : _municipiosIniciais = List.unmodifiable(municipios),
        _municipiosSelecionados = List.of(municipios),
        _points = pointsService ?? PointsFilterService(),
        _centroService = centroService ?? MunicipiosCentroService(),
        _ibge = ibgeService ?? IbgeService(),
        _projects = projectsService ?? ProjectsService(),
        _store = store ?? ProjectsStore.instance {
    areas.addListener(_agendarContagemAreas);
    if (versaoInicial != null) _carregarVersao(versaoInicial);
  }

  /// Projeto salvo aberto para ajustar e recalcular (#TG-86); null = novo.
  final int? projetoId;

  bool get editando => projetoId != null;

  /// Aplica a área e os filtros de uma versão salva do projeto. As cidades
  /// já chegam em `municipios` (as da mesma versão).
  void _carregarVersao(ProjectVersion v) {
    if (v.targetLayers.isNotEmpty) {
      _targetLayers = _ajustarNiveis(const [], v.targetLayers);
    }
    _conjCodes = v.conjCodes;
    _subCodes = v.subCodes;
    _clasSub = v.clasSub.map(MapFilterOptions.clasSubRotulo).toList();
    _cnaeCodes = v.cnaeCodes;
    _bairroNames = v.bairroNames;
    final cobertura = _soAs(v.lista('coverage_layers'), MapFilterOptions.camadasCobertura);
    if (cobertura.isNotEmpty) _coverageLayers = cobertura;
    final candidatas = _soAs(v.lista('candidate_layers'), MapFilterOptions.camadasCandidatas);
    if (candidatas.isNotEmpty) _candidateLayers = candidatas;
    for (final area in SelectedArea.fromGeoJson(v.polygon)) {
      areas.adicionar(area);
    }
  }

  final String nomeProjeto;
  final String distCode;
  final String distribuidoraLabel;

  final void Function(LatLng ponto)? onFocusPoint;
  final Duration focusDebounce;

  final MapAreasController areas = MapAreasController();

  final List<Municipio> _municipiosIniciais;
  final PointsFilterService _points;
  final MunicipiosCentroService _centroService;

  /// Centro de cada cidade da distribuidora (do backend); vazio até
  /// carregar ou se a chamada falhar.
  Map<int, LatLng> _centros = const {};
  final IbgeService _ibge;
  final ProjectsService _projects;
  final ProjectsStore _store;

  List<Municipio> _municipiosSelecionados;
  List<Municipio> _cidadesDisponiveis = [];

  List<String> _targetLayers =
      _ajustarNiveis(const [], MapFilterOptions.defaultTargetLayers);
  List<String> _conjCodes = [];
  List<String> _subCodes = [];
  List<String> _clasSub = [];
  List<String> _cnaeCodes = [];
  List<String> _bairroNames = [];
  List<String> _coverageLayers = List.of(MapFilterOptions.padraoCobertura);
  List<String> _candidateLayers = List.of(MapFilterOptions.padraoCandidatos);

  ContagemPontos? _contagem;
  bool _zoomBaixoDemais = false;

  bool _salvando = false;
  bool _projetoSalvo = false;
  int? _totalFinal;

  Timer? _focusTimer;
  bool _disposed = false;

  final Map<String, ContagemPontos> _totalPorArea = {};
  final Set<String> _contando = {};
  Timer? _contagemTimer;
  static const _contagemDebounce = Duration(milliseconds: 600);
  static const _contagemCacheMax = 60;


  List<Municipio> get municipiosSelecionados => _municipiosSelecionados;
  List<Municipio> get cidadesDisponiveis => _cidadesDisponiveis;
  List<String> get targetLayers => _targetLayers;
  List<String> get conjCodes => _conjCodes;
  List<String> get subCodes => _subCodes;
  List<String> get clasSub => _clasSub;
  List<String> get cnaeCodes => _cnaeCodes;
  List<String> get bairroNames => _bairroNames;
  List<String> get coverageLayers => _coverageLayers;
  List<String> get candidateLayers => _candidateLayers;

  /// Pontos a cobrir (consumidores) com os filtros atuais; null = contando.
  int? get totalPontos => _contagem?.pontos;

  /// Pontos a cobrir e candidatos, para mostrar na barra do mapa.
  ContagemPontos? get contagem => _contagem;
  bool get zoomBaixoDemais => _zoomBaixoDemais;

  bool get salvando => _salvando;
  bool get projetoSalvo => _projetoSalvo;
  int? get totalFinal => _totalFinal;


  Map<String, dynamic>? get areaGeoJson => areas.geoJson;

  List<String> get munCodes =>
      _municipiosSelecionados.map((m) => m.codigoIbge.toString()).toList();

  /// Centro das cidades escolhidas (média dos centros que vieram do
  /// backend). Sem esses dados ainda, usa o centro fixo antigo.
  LatLng get centroInicial {
    // Projeto aberto com área: começa no meio das áreas salvas.
    if (!areas.isEmpty) {
      final a = areas.areas;
      final norte = a.map((x) => x.north).reduce((p, q) => p > q ? p : q);
      final sul = a.map((x) => x.south).reduce((p, q) => p < q ? p : q);
      final oeste = a.map((x) => x.west).reduce((p, q) => p < q ? p : q);
      final leste = a.map((x) => x.east).reduce((p, q) => p > q ? p : q);
      return LatLng((norte + sul) / 2, (oeste + leste) / 2);
    }
    final centros = [
      for (final m in _municipiosIniciais)
        if (_centros[m.codigoIbge] case final c?) c,
    ];
    if (centros.isEmpty) {
      return MapRegions.centroInicial(
        _municipiosIniciais.map((m) => m.codigoIbge),
      );
    }
    final lat = centros.map((c) => c.latitude).reduce((a, b) => a + b);
    final lon = centros.map((c) => c.longitude).reduce((a, b) => a + b);
    return LatLng(lat / centros.length, lon / centros.length);
  }

  /// Busca os centros das cidades no backend. Sem eles (erro), o mapa
  /// segue com os centros fixos antigos.
  Future<void> carregarCentros() async {
    try {
      final centros = await _centroService.centros(distCode);
      if (_disposed || centros.isEmpty) return;
      _centros = centros;
      notifyListeners();
    } catch (_) {}
  }

  double get zoomInicial => MapRegions.zoomInicial;

  /// Já contou e não há nenhum ponto a cobrir com os filtros, cidades e
  /// áreas atuais (RN02 da US #11): o projeto não pode ser salvo.
  bool get semPontos => _contagem != null && _contagem!.pontos == 0;

  /// Só salva com nome e com pelo menos um ponto a cobrir já contado.
  bool get podeSalvar =>
      nomeProjeto.trim().isNotEmpty &&
      _contagem != null &&
      _contagem!.pontos > 0;

  FiltrosPontos get filtros => FiltrosPontos(
        distCode: distCode,
        targetLayers: _targetLayers,
        conjCodes: _conjCodes,
        subCodes: _subCodes
            .map((v) => normalizarTexto(v).toUpperCase().trim())
            .toList(),
        clasSub: _clasSub.map(MapFilterOptions.clasSubCode).toList(),
        cnaeCodes: _cnaeCodes,
        bairroNames:
            _bairroNames.map((v) => normalizarTexto(v).toUpperCase()).toList(),
        coverageLayers: _coverageLayers,
        candidateLayers: _candidateLayers,
      );


  Future<void> carregarCidadesDisponiveis() async {
    try {
      final cidades = await _ibge.buscarCidadesComDados(distCode);
      if (_disposed) return;
      _cidadesDisponiveis = cidades;
      notifyListeners();
    } catch (_) {
    }
  }

  LatLng? alternarCidade(Municipio m) {
    if (_municipiosSelecionados.contains(m)) {
      if (_municipiosSelecionados.length <= 1) return null;
      _municipiosSelecionados =
          _municipiosSelecionados.where((x) => x != m).toList();
      notifyListeners();
      _agendarContagemAreas();
      return null;
    }
    _municipiosSelecionados = [..._municipiosSelecionados, m];
    notifyListeners();
    _agendarContagemAreas();
    return _centros[m.codigoIbge] ?? MapRegions.centroFixoDe(m.codigoIbge);
  }


  void setBairros(List<String> valores) =>
      _alterarFiltro(() => _bairroNames = List.of(valores));

  void setTargetLayers(List<String> valores) => _alterarFiltro(
      () => _targetLayers = _ajustarNiveis(_targetLayers, valores));

  static List<String> _ajustarNiveis(List<String> antes, List<String> depois) {
    const todos = 'all';
    final acabouDeMarcarTodos =
        depois.contains(todos) && !antes.contains(todos);
    if (acabouDeMarcarTodos) return const [todos];
    final especificos = depois.where((v) => v != todos).toList();
    if (especificos.isEmpty) return const [todos];
    return especificos;
  }

  /// Camadas que são pontos a cobrir (#TG-92). Pelo menos uma.
  void setCoverageLayers(List<String> valores) {
    final camadas = _soAs(valores, MapFilterOptions.camadasCobertura);
    if (camadas.isEmpty) return;
    _alterarFiltro(() => _coverageLayers = camadas);
  }

  /// Camadas candidatas a gateway (#TG-92). Pelo menos uma.
  void setCandidateLayers(List<String> valores) {
    final camadas = _soAs(valores, MapFilterOptions.camadasCandidatas);
    if (camadas.isEmpty) return;
    _alterarFiltro(() => _candidateLayers = camadas);
  }

  /// Só as opções válidas, na ordem das opções (a mesma lista dá o mesmo
  /// filtro, qualquer que seja a ordem em que foi marcada).
  static List<String> _soAs(List<String> valores, List<String> opcoes) =>
      [for (final o in opcoes) if (valores.contains(o)) o];

  void setConjCodes(List<String> valores) =>
      _alterarFiltro(() => _conjCodes = List.of(valores));

  void setSubCodes(List<String> valores) =>
      _alterarFiltro(() => _subCodes = List.of(valores));

  void setClasSub(List<String> valores) =>
      _alterarFiltro(() => _clasSub = List.of(valores));

  void setCnaeCodes(List<String> valores) =>
      _alterarFiltro(() => _cnaeCodes = List.of(valores));

  void _alterarFiltro(VoidCallback alterar) {
    alterar();
    notifyListeners();
    _pedidoCentralizar++; // invalida uma centralização já em andamento
    _focusTimer?.cancel();
    _focusTimer = Timer(focusDebounce, _centralizarEmFiltroAtual);
    _agendarContagemAreas(); // filtro novo muda o total de cada área
  }


  String _chaveArea(SelectedArea a, FiltrosPontos f) =>
      '${a.toRing().map((c) => '${c[0]},${c[1]}').join(';')}|${f.hashCode}|${munCodes.join(",")}';

  ContagemPontos? totalNaArea(SelectedArea a) =>
      _totalPorArea[_chaveArea(a, filtros)];

  void _agendarContagemAreas() {
    _contagemTimer?.cancel();
    if (areas.isEmpty) return;
    _contagemTimer = Timer(_contagemDebounce, _contarAreas);
  }

  Future<void> _contarAreas() async {
    final f = filtros;
    if (_totalPorArea.length > _contagemCacheMax) _totalPorArea.clear();

    for (final area in areas.areas) {
      final chave = _chaveArea(area, f);
      if (_totalPorArea.containsKey(chave) || _contando.contains(chave)) {
        continue;
      }
      _contando.add(chave);
      try {
        final r = await _points.buscarPontos(
          distCodes: [distCode],
          munCodes: munCodes,
          polygonGeoJson: SelectedArea.toGeoJson([area]),
          targetLayers: f.targetLayers,
          conjCodes: f.conjCodes,
          subCodes: f.subCodes,
          clasSub: f.clasSub,
          cnaeCodes: f.cnaeCodes,
          bairroNames: f.bairroNames,
          coverageLayers: f.coverageLayers,
          candidateLayers: f.candidateLayers,
          countOnly: true,
        );
        if (_disposed) return;
        _totalPorArea[chave] = r.contagem;
        notifyListeners();
      } catch (_) {
      } finally {
        _contando.remove(chave);
      }
      if (filtros != f) return;
    }
  }


  void setTotalPontos(ContagemPontos contagem) {
    if (_contagem == contagem) return;
    _contagem = contagem;
    notifyListeners();
  }

  void setZoomBaixoDemais(bool valor) {
    if (_zoomBaixoDemais == valor) return;
    _zoomBaixoDemais = valor;
    notifyListeners();
  }


  Future<PointsFilterResult> _buscarPontosDosFiltros({bool countOnly = false}) {
    final f = filtros;
    final geo = areas.geoJson;
    return _points.buscarPontos(
      distCodes: [distCode],
      munCodes: munCodes,
      polygonGeoJson: geo,
      targetLayers: f.targetLayers,
      conjCodes: f.conjCodes,
      subCodes: f.subCodes,
      clasSub: f.clasSub,
      cnaeCodes: f.cnaeCodes,
      bairroNames: f.bairroNames,
      coverageLayers: f.coverageLayers,
      candidateLayers: f.candidateLayers,
      countOnly: countOnly,
    );
  }

  Future<LatLng?> localizarFiltroAtual() async {
    if (!filtros.temFiltroAtivo) return null;
    try {
      final resultado = await _buscarPontosDosFiltros();
      if (resultado.features.isEmpty) return null;

      final alvo = resultado.features.firstWhere(
        (f) => (f['geometry'] as Map<String, dynamic>?)?['type'] == 'Point',
        orElse: () => resultado.features.first,
      );
      return MapPoint.fromFeature(alvo)?.position;
    } catch (_) {
      return null;
    }
  }

  int _pedidoCentralizar = 0;

  Future<void> _centralizarEmFiltroAtual() async {
    final meuPedido = ++_pedidoCentralizar;
    final filtrosPedidos = filtros;
    final ponto = await localizarFiltroAtual();
    if (_disposed || ponto == null) return;
    if (meuPedido != _pedidoCentralizar || filtros != filtrosPedidos) return;
    onFocusPoint?.call(ponto);
  }

  /// `filter_params` gravado no histórico do projeto e lido pelo motor.
  Map<String, dynamic> get filterParams {
    final f = filtros;
    return {
      'dist_codes': [distCode],
      'mun_codes': munCodes,
      'polygon_geojson': areas.geoJson,
      'target_layers': f.targetLayers,
      'conj_codes': f.conjCodes,
      'sub_codes': f.subCodes,
      'clas_sub': f.clasSub,
      'cnae_codes': f.cnaeCodes,
      'bairro_names': f.bairroNames,
      'coverage_layers': f.coverageLayers,
      'candidate_layers': f.candidateLayers,
    };
  }

  /// Salva o projeto novo ou, se for um projeto aberto ([editando]),
  /// recalcula gerando uma versão nova.
  Future<bool> salvarProjeto() async {
    if (!podeSalvar || _salvando) return false;
    _salvando = true;
    _projetoSalvo = false;
    notifyListeners();

    try {
      final resultadoPontos = await _buscarPontosDosFiltros(countOnly: true);
      // Confere de novo no servidor: sem ponto a cobrir não envia ao motor.
      if (resultadoPontos.totalPoints == 0) {
        _contagem = resultadoPontos.contagem;
        if (_disposed) return false;
        _salvando = false;
        notifyListeners();
        return false;
      }
      final geo = areas.geoJson;
      final id = projetoId;
      if (id == null) {
        final projetoCriado = await _projects.criar(
          name: nomeProjeto,
          distCode: distCode,
          geometry: geo == null ? null : jsonEncode(geo),
          filterParams: filterParams,
        );
        _store.adicionar(projetoCriado);
      } else {
        // Projeto aberto (#TG-86): nova versão e novo cálculo (#TG-84).
        final recalculado = await _projects.recalcular(
          id: id,
          geometry: geo == null ? null : jsonEncode(geo),
          filterParams: filterParams,
        );
        _store.atualizar(recalculado);
      }

      if (_disposed) return true;
      _totalFinal = resultadoPontos.totalPoints;
      _projetoSalvo = true;
      _salvando = false;
      notifyListeners();
      return true;
    } catch (_) {
      if (_disposed) return false;
      _salvando = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _focusTimer?.cancel();
    _contagemTimer?.cancel();
    areas.removeListener(_agendarContagemAreas);
    areas.dispose();
    super.dispose();
  }
}
