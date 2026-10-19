import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:tecsys_app/features/map/data/constants/map_config.dart';
import 'package:tecsys_app/features/map/data/models/filtros_pontos.dart';
import 'package:tecsys_app/features/map/data/models/map_point.dart';
import 'package:tecsys_app/features/map/data/models/map_viewport.dart';
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

  /// GeoJSON das áreas selecionadas (null = nenhuma).
  final Map<String, dynamic>? Function()? lerAreas;

  final ValueChanged<int>? onTotalChanged;
  final ValueChanged<bool>? onZoomMuitoBaixo;
  final Duration debounce;
  final Duration revealDelay;
  final PointsFilterService _service;

  /// Filtros usados na próxima busca (o widget atualiza ao mudarem).
  FiltrosPontos filtros;

  Timer? _debounce;
  int _pedidoId = 0;
  bool _disposed = false;

  String? _chaveContagemAreas;
  int? _totalAreas;

  List<MapPoint> _pontos = [];
  bool _carregando = false;

  /// Pontos já revelados no mapa (chegam aos poucos, em lotes).
  List<MapPoint> get pontos => _pontos;
  bool get carregando => _carregando;

  void agendarBusca() {
    _debounce?.cancel();
    _debounce = Timer(debounce, buscarAgora);
  }

  Future<PointsFilterResult> _buscar(
    FiltrosPontos f,
    Map<String, dynamic> poligono, {
    bool countOnly = false,
  }) {
    return _service.buscarPontos(
      distCodes: [f.distCode],
      polygonGeoJson: poligono,
      targetLayers: f.targetLayers,
      conjCodes: f.conjCodes,
      subCodes: f.subCodes,
      clasSub: f.clasSub,
      cnaeCodes: f.cnaeCodes,
      bairroNames: f.bairroNames,
      countOnly: countOnly,
    );
  }

  Future<void> buscarAgora() async {
    final viewport = lerViewport();
    if (viewport.zoom < MapConfig.minZoomToSearch) {
      _pedidoId++; // invalida buscas em andamento
      _pontos = [];
      _carregando = false;
      _notificar();
      onZoomMuitoBaixo?.call(true);
      onTotalChanged?.call(0);
      return;
    }
    onZoomMuitoBaixo?.call(false);

    final meuPedido = ++_pedidoId;
    _carregando = true;
    _notificar();

    try {
      final f = filtros;
      final areas = lerAreas?.call();
      final chave = areas == null ? null : '${jsonEncode(areas)}|${f.hashCode}';
      final precisaContar = chave != null && chave != _chaveContagemAreas;

      final respostas = await Future.wait([
        _buscar(f, viewport.toPolygonGeoJson()),
        if (precisaContar) _buscar(f, areas!, countOnly: true),
      ]);
      if (_disposed || meuPedido != _pedidoId) return;

      final resultado = respostas[0];
      if (precisaContar) {
        _chaveContagemAreas = chave;
        _totalAreas = respostas[1].totalPoints;
      }

      final novos = <MapPoint>[
        for (final feature
            in resultado.features.take(MapConfig.maxRenderedPoints))
          if (MapPoint.fromFeature(feature) case final ponto?) ponto,
      ];
      _carregando = false;
      _notificar();
      onTotalChanged?.call(
        areas != null ? (_totalAreas ?? 0) : resultado.totalPoints,
      );
      await _revelarEmLotes(novos, meuPedido);
    } catch (_) {
      if (_disposed || meuPedido != _pedidoId) return;
      _carregando = false;
      _notificar();
    }
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