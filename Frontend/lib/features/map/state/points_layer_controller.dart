import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:tecsys_app/features/map/data/constants/map_config.dart';
import 'package:tecsys_app/features/map/data/models/filtros_pontos.dart';
import 'package:tecsys_app/features/map/data/models/map_point.dart';
import 'package:tecsys_app/features/map/data/models/map_viewport.dart';
import 'package:tecsys_app/features/map/data/models/point_cluster.dart';
import 'package:tecsys_app/features/map/data/services/points_filter_service.dart';

class PointsLayerController extends ChangeNotifier {
  PointsLayerController({
    required this.lerViewport,
    required this.filtros,
    this.lerAreas,
    this.onTotalChanged,
    this.onZoomMuitoBaixo,
    this.debounce = MapConfig.searchDebounce,
    this.revealDelay = MapConfig.revealBatchDelay,
    PointsFilterService? service,
  }) : _service = service ?? PointsFilterService();

  final MapViewport Function() lerViewport;

  final Map<String, dynamic>? Function()? lerAreas;

  final ValueChanged<int>? onTotalChanged;
  final ValueChanged<bool>? onZoomMuitoBaixo;
  final Duration debounce;
  final Duration revealDelay;
  final PointsFilterService _service;

  /// Filtros usados na próxima busca (o widget atualiza ao mudarem).
  FiltrosPontos filtros;

  List<String> munCodes = const [];

  Timer? _debounce;
  int _pedidoId = 0;
  bool _disposed = false;

  String? _chaveContagemAreas;
  int? _totalAreas;

  String? _chaveVisaoGeral;
  List<MapPoint> _celulas = const [];
  String? _chaveCarregando;
  Future<List<MapPoint>>? _visaoGeralEmAndamento;
  bool _carregandoVisaoGeral = false;
  int _totalVisaoGeral = 0;
  String? _erro;

  String? _chaveTotal;
  int _totalCidades = 0;

  String? _chaveDetalhe;
  MapViewport? _areaDetalhe;
  List<MapPoint> _celulasDetalhe = const [];

  List<MapPoint> _pontos = [];
  Agrupamento _agrupamento = Agrupamento.vazio();
  String? _assinaturaBolhas;
  bool _agrupado = false;
  bool _carregando = false;

  List<MapPoint> get pontos => _pontos;

  Agrupamento get agrupamento => _agrupamento;

  bool get agrupado => _agrupado;

  bool get carregando => _carregando;

  bool get carregandoVisaoGeral => _carregandoVisaoGeral;

  String? get erro => _erro;

  void limparErro() {
    _erro = null;
    _notificar();
  }
  void agendarBusca({Duration? aguardar}) {
    _debounce?.cancel();
    if (aguardar != null) {
      _debounce = Timer(aguardar, () => agendarBusca());
      return;
    }
    if (_temCelulasProntas(lerViewport())) {
      buscarAgora();
      return;
    }
    _debounce = Timer(debounce, buscarAgora);
  }

  bool _temCelulasProntas(MapViewport v) {
    if (v.zoom < MapConfig.minZoomToSearch) {
      return _chaveVisaoGeral == _chaveFiltros(filtros);
    }
    if (v.zoom < MapConfig.minZoomIndividual) {
      return _chaveDetalhe == _chaveDetalheDe(filtros, v) &&
          _contem(_areaDetalhe, v);
    }
    return false;
  }

  String _chaveFiltros(FiltrosPontos f) => jsonEncode([
        munCodes,
        f.distCode,
        f.targetLayers,
        f.conjCodes,
        f.subCodes,
        f.clasSub,
        f.cnaeCodes,
        f.bairroNames,
      ]);

  String _chaveDetalheDe(FiltrosPontos f, MapViewport v) =>
      '${_chaveFiltros(f)}|${v.zoom.floor()}';

  static bool _contem(MapViewport? fora, MapViewport dentro) =>
      fora != null &&
      dentro.west >= fora.west &&
      dentro.east <= fora.east &&
      dentro.south >= fora.south &&
      dentro.north <= fora.north;

  Future<PointsFilterResult> _buscar(
    FiltrosPontos f,
    Map<String, dynamic>? poligono, {
    bool countOnly = false,
    double? clusterCell,
    int? limit,
  }) {
    return _service.buscarPontos(
      distCodes: [f.distCode],
      munCodes: munCodes.isNotEmpty ? munCodes : null,
      polygonGeoJson: poligono,
      targetLayers: f.targetLayers,
      conjCodes: f.conjCodes,
      subCodes: f.subCodes,
      clasSub: f.clasSub,
      cnaeCodes: f.cnaeCodes,
      bairroNames: f.bairroNames,
      countOnly: countOnly,
      clusterCell: clusterCell,
      limit: limit,
    );
  }

  static List<MapPoint> _celulasDe(PointsFilterResult r) => [
        for (final feature in r.features)
          if (MapPoint.fromFeature(feature) case final c?) c,
      ];

  Future<List<MapPoint>> carregarVisaoGeral() {
    final f = filtros;
    final chave = _chaveFiltros(f);
    if (chave == _chaveVisaoGeral) return Future.value(_celulas);
    if (chave == _chaveCarregando && _visaoGeralEmAndamento != null) {
      return _visaoGeralEmAndamento!;
    }

    _chaveCarregando = chave;
    _carregandoVisaoGeral = true;
    _erro = null;
    _notificar();

    void terminou() {
      if (_chaveCarregando != chave) return; // já pediram outra
      _chaveCarregando = null;
      _visaoGeralEmAndamento = null;
      _carregandoVisaoGeral = false;
      _notificar();
    }

    final futuro = _buscar(
      f,
      null, 
      clusterCell: MapConfig.overviewCellDegrees,
    ).timeout(MapConfig.overviewTimeout).then((r) {
      final celulas = _celulasDe(r);
      if (celulas.isNotEmpty && !celulas.first.isCluster) {
        throw StateError('backend sem agrupamento');
      }
      if (_chaveCarregando == chave) {
        _chaveVisaoGeral = chave;
        _celulas = celulas;
        _totalVisaoGeral = r.totalPoints;
      }
      terminou();
      return celulas;
    }).catchError((Object e, StackTrace st) {
      if (_chaveCarregando == chave) {
        _erro = e is StateError
            ? 'O backend não agrupou os pontos: ele está desatualizado. '
                'Reconstrua com ./scripts/up-local.sh.'
            : e is TimeoutException
                ? 'Os pontos demoraram demais para carregar. Tente filtrar '
                    'menos cidades ou tente de novo.'
                : 'Não foi possível carregar os pontos do mapa.';
      }
      terminou();
      Error.throwWithStackTrace(e, st);
    });

    _visaoGeralEmAndamento = futuro;
    return futuro;
  }

  Future<List<MapPoint>> _carregarDetalhe(
    FiltrosPontos f,
    MapViewport v,
    int meuPedido,
  ) async {
    final chave = _chaveDetalheDe(f, v);
    if (chave == _chaveDetalhe && _contem(_areaDetalhe, v)) {
      return _celulasDetalhe;
    }

    final area = _expandir(v, MapConfig.detailFetchMargin);
    // Célula = uma fração da bolha, em graus, no nível de zoom atual.
    final grausPorPixel = 360 / (256 * math.pow(2, v.zoom.floor()));
    final celula = grausPorPixel *
        MapConfig.detailPixelSize /
        MapConfig.detailCellsPerBubble;

    _carregando = true;
    _notificar();
    final r = await _buscar(f, area.toPolygonGeoJson(), clusterCell: celula);
    final celulas = _celulasDe(r);
    if (!_disposed && meuPedido == _pedidoId) {
      _chaveDetalhe = chave;
      _areaDetalhe = area;
      _celulasDetalhe = celulas;
    }
    return celulas;
  }

  static MapViewport _expandir(MapViewport v, double margem) {
    final dx = (v.east - v.west) * margem;
    final dy = (v.north - v.south) * margem;
    return MapViewport(
      zoom: v.zoom,
      west: v.west - dx,
      east: v.east + dx,
      south: math.max(-85.0, v.south - dy),
      north: math.min(85.0, v.north + dy),
    );
  }

  Future<void> buscarAgora() async {
    final viewport = lerViewport();
    onZoomMuitoBaixo?.call(false);

    final meuPedido = ++_pedidoId;
    final f = filtros;
    final areas = lerAreas?.call();
    final chaveAreas =
        areas == null ? null : '${jsonEncode(areas)}|${_chaveFiltros(f)}';
    final precisaContar =
        chaveAreas != null && chaveAreas != _chaveContagemAreas;

    try {
      final contagem =
          precisaContar ? _buscar(f, areas!, countOnly: true) : null;

      if (viewport.zoom < MapConfig.minZoomToSearch) {
        final celulas = await carregarVisaoGeral();
        if (_disposed || meuPedido != _pedidoId) return;
        _mostrarBolhas(celulas, viewport, MapConfig.clusterPixelSize, areas);
      } else if (viewport.zoom < MapConfig.minZoomIndividual) {
        final celulas = await _carregarDetalhe(f, viewport, meuPedido);
        if (_disposed || meuPedido != _pedidoId) return;
        _mostrarBolhas(celulas, viewport, MapConfig.detailPixelSize, areas);
      } else {
        await _mostrarPontos(f, viewport, meuPedido, areas != null);
      }

      if (contagem != null) {
        final total = (await contagem).totalPoints;
        if (_disposed || meuPedido != _pedidoId) return;
        _chaveContagemAreas = chaveAreas;
        _totalAreas = total;
      }
      if (_disposed || meuPedido != _pedidoId) return;
      if (areas != null) {
        onTotalChanged?.call(_totalAreas ?? 0);
      } else {
        final total = await _totalDasCidades(f);
        if (_disposed || meuPedido != _pedidoId) return;
        onTotalChanged?.call(total);
      }
    } catch (_) {
      if (_disposed || meuPedido != _pedidoId) return;
      _carregando = false;
      _notificar();
    }
  }

  Future<int> _totalDasCidades(FiltrosPontos f) async {
    final chave = _chaveFiltros(f);
    if (chave == _chaveVisaoGeral) return _totalVisaoGeral;
    if (chave == _chaveTotal) return _totalCidades;
    final r = await _buscar(f, null, countOnly: true);
    _chaveTotal = chave;
    _totalCidades = r.totalPoints;
    return _totalCidades;
  }

  void _mostrarBolhas(
    List<MapPoint> celulas,
    MapViewport viewport,
    double pixels,
    Map<String, dynamic>? areas,
  ) {
    final assinatura = '${viewport.zoom.toStringAsFixed(2)}|$pixels|'
        '${identityHashCode(celulas)}';
    if (assinatura != _assinaturaBolhas) {
      _assinaturaBolhas = assinatura;
      _agrupamento = Agrupamento.de(celulas, viewport.zoom, pixels);
    }
    _agrupado = true;
    _carregando = false;
    _notificar();

  }

  Future<void> _mostrarPontos(
    FiltrosPontos f,
    MapViewport viewport,
    int meuPedido,
    bool temAreas,
  ) async {
    _carregando = true;
    _notificar();

    final resultado = await _buscar(
      f,
      viewport.toPolygonGeoJson(),
      limit: MapConfig.maxRenderedPoints,
    );
    if (_disposed || meuPedido != _pedidoId) return;

    final novos = <MapPoint>[
      for (final feature in resultado.features.take(MapConfig.maxRenderedPoints))
        if (MapPoint.fromFeature(feature) case final ponto?) ponto,
    ];
    _carregando = false;

    _agrupado = false;
    _assinaturaBolhas = null; // ao voltar para as bolhas, reagrupa
    _notificar();
    await _revelarEmLotes(novos, meuPedido);
  }

  Set<String> _idsDe(List<MapPoint> lista) =>
      lista.map((p) => p.id).whereType<String>().toSet();

  /// Mostra os pontos novos em lotes (para não travar a tela) e, no fim,
  /// remove os que saíram da busca atual.
  Future<void> _revelarEmLotes(List<MapPoint> todos, int meuPedido) async {
    final jaMostrando = _idsDe(_pontos);
    final novos = todos.where((p) {
      final id = p.id;
      return id == null || !jaMostrando.contains(id);
    }).toList();

    final acumulado = List<MapPoint>.of(_pontos);
    for (var i = 0; i < novos.length; i += MapConfig.revealBatchSize) {
      if (_disposed || meuPedido != _pedidoId) return;
      final fim = (i + MapConfig.revealBatchSize < novos.length)
          ? i + MapConfig.revealBatchSize
          : novos.length;
      acumulado.addAll(novos.sublist(i, fim));
      _pontos = List.of(acumulado);
      _notificar();
      await Future.delayed(revealDelay);
    }

    if (_disposed || meuPedido != _pedidoId) return;
    final idsAtuais = _idsDe(todos);
    _pontos = _pontos.where((p) {
      final id = p.id;
      return id == null || idsAtuais.contains(id);
    }).toList();
    _notificar();
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
