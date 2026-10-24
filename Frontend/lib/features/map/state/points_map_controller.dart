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
import 'package:tecsys_app/features/map/data/services/points_filter_service.dart';
import 'package:tecsys_app/features/map/state/map_areas_controller.dart';
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
    this.focusDebounce = const Duration(milliseconds: 600),
    PointsFilterService? pointsService,
    IbgeService? ibgeService,
    ProjectsService? projectsService,
    ProjectsStore? store,
  })  : _municipiosIniciais = List.unmodifiable(municipios),
        _municipiosSelecionados = List.of(municipios),
        _points = pointsService ?? PointsFilterService(),
        _ibge = ibgeService ?? IbgeService(),
        _projects = projectsService ?? ProjectsService(),
        _store = store ?? ProjectsStore.instance {
    areas.addListener(_agendarContagemAreas);
  }

  final String nomeProjeto;
  final String distCode;
  final String distribuidoraLabel;

  final void Function(LatLng ponto)? onFocusPoint;
  final Duration focusDebounce;

  final MapAreasController areas = MapAreasController();

  final List<Municipio> _municipiosIniciais;
  final PointsFilterService _points;
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

  int? _totalPontos;
  bool _zoomBaixoDemais = false;

  bool _salvando = false;
  bool _projetoSalvo = false;
  int? _totalFinal;

  Timer? _focusTimer;
  bool _disposed = false;

  final Map<String, int> _totalPorArea = {};
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

  int? get totalPontos => _totalPontos;
  bool get zoomBaixoDemais => _zoomBaixoDemais;

  bool get salvando => _salvando;
  bool get projetoSalvo => _projetoSalvo;
  int? get totalFinal => _totalFinal;


  Map<String, dynamic>? get areaGeoJson => areas.geoJson;

  List<String> get munCodes =>
      _municipiosSelecionados.map((m) => m.codigoIbge.toString()).toList();

  LatLng get centroInicial => MapRegions.centroInicial(
        _municipiosIniciais.map((m) => m.codigoIbge),
      );

  double get zoomInicial => MapRegions.zoomInicial;

  bool get podeSalvar => nomeProjeto.trim().isNotEmpty;

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
      );


  Future<void> carregarCidadesDisponiveis() async {
    try {
      final cidades = await _ibge.buscarCidadesComDados();
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
    return MapRegions.centroFixoDe(m.codigoIbge);
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
      '${a.north},${a.south},${a.west},${a.east}|${f.hashCode}|${munCodes.join(",")}';

  int? totalNaArea(SelectedArea a) => _totalPorArea[_chaveArea(a, filtros)];

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
          countOnly: true,
        );
        if (_disposed) return;
        _totalPorArea[chave] = r.totalPoints;
        notifyListeners();
      } catch (_) {
      } finally {
        _contando.remove(chave);
      }
      if (filtros != f) return;
    }
  }


  void setTotalPontos(int total) {
    if (_totalPontos == total) return;
    _totalPontos = total;
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

  Future<bool> salvarProjeto() async {
    if (!podeSalvar || _salvando) return false;
    _salvando = true;
    _projetoSalvo = false;
    notifyListeners();

    try {
      final resultadoPontos = await _buscarPontosDosFiltros(countOnly: true);
      final f = filtros;

      final geo = areas.geoJson;
      final projetoCriado = await _projects.criar(
        name: nomeProjeto,
        distCode: distCode,
        geometry: geo == null ? null : jsonEncode(geo),
        filterParams: {
          'dist_codes': [distCode],
          'mun_codes': munCodes,
          'polygon_geojson': geo,
          'target_layers': f.targetLayers,
          'conj_codes': f.conjCodes,
          'sub_codes': f.subCodes,
          'clas_sub': f.clasSub,
          'cnae_codes': f.cnaeCodes,
          'bairro_names': f.bairroNames,
        },
      );
      _store.adicionar(projetoCriado);

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
