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

/// Busca o que o mapa mostra, em três faixas de zoom:
///
/// * **Visão geral** (abaixo de [MapConfig.minZoomToSearch]): bolhas com
///   o número de pontos, vindas de todos os pontos da distribuidora
///   agrupados no banco numa grade de ~1 km. Carregada UMA vez por
///   conjunto de filtros; arrastar e dar zoom só reagrupa no app.
/// * **Bolhas menores** (até [MapConfig.minZoomIndividual]): a mesma ideia
///   numa grade fina, mas só de uma área um pouco maior que a tela. Arrastar
///   dentro dessa área não busca de novo.
/// * **Pontos individuais** (a partir de [MapConfig.minZoomIndividual]):
///   os pontos da tela, no máximo [MapConfig.maxRenderedPoints], revelados
///   em lotes.
///
/// Respostas atrasadas (de uma busca já substituída) são descartadas.
/// Com áreas selecionadas ([lerAreas]), o total informado é o de dentro
/// delas; essa contagem só é refeita quando as áreas ou os filtros mudam.
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

  // Cache da contagem dentro das áreas (não depende da tela).
  String? _chaveContagemAreas;
  int? _totalAreas;

  // Visão geral: células de toda a distribuidora para os filtros atuais.
  String? _chaveVisaoGeral;
  List<MapPoint> _celulas = const [];
  String? _chaveCarregando;
  Future<List<MapPoint>>? _visaoGeralEmAndamento;
  bool _carregandoVisaoGeral = false;

  // Bolhas menores: células da grade fina de uma área em volta da tela.
  String? _chaveDetalhe;
  MapViewport? _areaDetalhe;
  List<MapPoint> _celulasDetalhe = const [];

  List<MapPoint> _pontos = [];
  Agrupamento _agrupamento = Agrupamento.vazio();
  String? _assinaturaBolhas;
  bool _agrupado = false;
  bool _carregando = false;

  /// Pontos individuais já revelados (zoom próximo).
  List<MapPoint> get pontos => _pontos;

  /// Bolhas atuais. Um objeto novo a cada reagrupamento: o mapa anima a
  /// passagem do anterior para este.
  Agrupamento get agrupamento => _agrupamento;

  /// True mostrando bolhas; false mostrando pontos individuais. A lista
  /// do outro modo é mantida para o mapa esmaecê-la suavemente.
  bool get agrupado => _agrupado;

  /// Busca rápida em andamento (indicador pequeno no topo).
  bool get carregando => _carregando;

  /// Carregando a visão geral (tela de carregamento por cima do mapa).
  bool get carregandoVisaoGeral => _carregandoVisaoGeral;

  /// Agenda a próxima busca. Com [aguardar], espera esse tempo sem
  /// novos pedidos antes de rodar (rolagem / pinça do touchpad, que manda
  /// um evento por "tique" e não tem evento de fim).
  void agendarBusca({Duration? aguardar}) {
    _debounce?.cancel();
    if (aguardar != null) {
      _debounce = Timer(aguardar, () => agendarBusca());
      return;
    }
    // Bolhas que já estão em memória: reagrupar é local e instantâneo,
    // não precisa esperar o debounce.
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

  /// Identifica os filtros que mudam o resultado (FiltrosPontos é
  /// recriado a cada build, então não dá para comparar a instância).
  String _chaveFiltros(FiltrosPontos f) => jsonEncode([
        f.distCode,
        f.targetLayers,
        f.conjCodes,
        f.subCodes,
        f.clasSub,
        f.cnaeCodes,
        f.bairroNames,
      ]);

  /// As bolhas menores dependem do nível inteiro de zoom (a grade fica
  /// mais fina a cada nível).
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

  /// Carrega (ou devolve do cache) a visão geral dos filtros atuais.
  /// Pedidos repetidos enquanto carrega reaproveitam a mesma busca, para
  /// não pedir a distribuidora inteira duas vezes.
  Future<List<MapPoint>> carregarVisaoGeral() {
    final f = filtros;
    final chave = _chaveFiltros(f);
    if (chave == _chaveVisaoGeral) return Future.value(_celulas);
    if (chave == _chaveCarregando && _visaoGeralEmAndamento != null) {
      return _visaoGeralEmAndamento!;
    }

    _chaveCarregando = chave;
    _carregandoVisaoGeral = true;
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
      null, // sem polígono: a distribuidora inteira
      clusterCell: MapConfig.overviewCellDegrees,
    ).then((r) {
      final celulas = _celulasDe(r);
      if (_chaveCarregando == chave) {
        _chaveVisaoGeral = chave;
        _celulas = celulas;
      }
      terminou();
      return celulas;
    }, onError: (Object e, StackTrace st) {
      terminou();
      Error.throwWithStackTrace(e, st);
    });

    _visaoGeralEmAndamento = futuro;
    return futuro;
  }

  /// Células das bolhas menores para a tela [v]: do cache se a tela ainda
  /// está dentro da área já buscada; senão busca a tela com uma margem em
  /// volta (assim pequenos arrastes não buscam de novo).
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
    // Com as bolhas não há mais "zoom baixo demais": sempre aparece algo.
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
      if (areas != null) onTotalChanged?.call(_totalAreas ?? 0);
    } catch (_) {
      if (_disposed || meuPedido != _pedidoId) return;
      _carregando = false;
      _notificar();
    }
  }

  /// Agrupa [celulas] em bolhas no zoom atual. O total é o dos pontos da
  /// tela (sem áreas selecionadas).
  void _mostrarBolhas(
    List<MapPoint> celulas,
    MapViewport viewport,
    double pixels,
    Map<String, dynamic>? areas,
  ) {
    // Mesmo zoom e mesmas células = mesmas bolhas (a grade é fixa no
    // mundo); só reagrupa, e anima, quando algo mudou de fato.
    final assinatura = '${viewport.zoom.toStringAsFixed(2)}|$pixels|'
        '${identityHashCode(celulas)}';
    if (assinatura != _assinaturaBolhas) {
      _assinaturaBolhas = assinatura;
      _agrupamento = Agrupamento.de(celulas, viewport.zoom, pixels);
    }
    // Os pontos individuais ficam na lista: o mapa os esmaece.
    _agrupado = true;
    _carregando = false;
    _notificar();

    if (areas == null) {
      var naTela = 0;
      for (final c in celulas) {
        final p = c.position;
        if (p.latitude >= viewport.south &&
            p.latitude <= viewport.north &&
            p.longitude >= viewport.west &&
            p.longitude <= viewport.east) {
          naTela += c.clusterCount;
        }
      }
      onTotalChanged?.call(naTela);
    }
  }

  /// Zoom próximo: busca os pontos individuais da tela e revela em lotes.
  /// O backend já corta em [MapConfig.maxRenderedPoints]: antes vinham
  /// TODOS os pontos da tela (milhares, em área densa) e o app jogava o
  /// resto fora depois de baixar e ler tudo.
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
    if (!temAreas) onTotalChanged?.call(resultado.totalPoints);

    // As bolhas ficam na lista: o mapa as esmaece enquanto os pontos entram.
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
