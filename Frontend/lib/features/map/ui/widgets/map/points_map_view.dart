import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:tecsys_app/features/map/data/constants/map_config.dart';
import 'package:tecsys_app/features/map/data/models/filtros_pontos.dart';
import 'package:tecsys_app/features/map/data/models/map_point.dart';
import 'package:tecsys_app/features/map/data/models/map_viewport.dart';
import 'package:tecsys_app/features/map/data/models/point_cluster.dart';
import 'package:tecsys_app/features/map/data/models/selected_area.dart';
import 'package:tecsys_app/features/map/state/map_areas_controller.dart';
import 'package:tecsys_app/features/map/state/points_layer_controller.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/area_selection_overlay.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/cluster_bubbles_layer.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/map_coordinates_panel.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/map_legend.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/map_loading_indicator.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/map_overview_loading.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/map_toolbar.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/point_detail_sheet.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/point_markers_layer.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/selected_areas_layer.dart';

class PointsMapView extends StatefulWidget {
  final FiltrosPontos filtros;

  final List<String> municipios;
  final MapAreasController areas;
  final LatLng initialCenter;
  final double initialZoom;
  final ValueChanged<int>? onTotalChanged;
  final ValueChanged<bool>? onZoomMuitoBaixo;

  const PointsMapView({
    super.key,
    required this.filtros,
    this.municipios = const [],
    required this.areas,
    required this.initialCenter,
    this.initialZoom = MapConfig.defaultZoom,
    this.onTotalChanged,
    this.onZoomMuitoBaixo,
  });

  @override
  State<PointsMapView> createState() => PointsMapViewState();
}

class PointsMapViewState extends State<PointsMapView>
    with SingleTickerProviderStateMixin {
  final MapController mapController = MapController();
  late final PointsLayerController _layer;
  StreamSubscription<MapEvent>? _mapEventsSub;

  bool _mostrarRelevo = false;
  bool _selecionando = false;

  final _selecao = ValueNotifier<Rect?>(null);

  late final _centro = ValueNotifier<LatLng>(widget.initialCenter);

  final _destaque = ValueNotifier<int?>(null);
  Timer? _timerPiscar;
  late int _ultimoPedidoFoco;
  late int _ultimaVersaoAreas;

  Size _tamanhoMapa = Size.zero;

  late final AnimationController _camAnim = AnimationController(
    vsync: this,
    duration: MapStyles.cameraAnimDuration,
  );
  VoidCallback? _camPasso;

  void _animarPara(LatLng centro, double zoom) {
    final camera = mapController.camera;
    final c0 = camera.center;
    final z0 = camera.zoom;
    final curva = Curves.easeInOutCubic;

    if (_camPasso != null) _camAnim.removeListener(_camPasso!);
    _camPasso = () {
      final t = curva.transform(_camAnim.value);
      mapController.move(
        LatLng(
          c0.latitude + (centro.latitude - c0.latitude) * t,
          c0.longitude + (centro.longitude - c0.longitude) * t,
        ),
        z0 + (zoom - z0) * t,
      );
    };
    _camAnim.addListener(_camPasso!);
    _camAnim.forward(from: 0).whenComplete(() {
      if (mounted) _layer.agendarBusca();
    });
  }

  void moverPara(LatLng centro, double zoom) {
    mapController.move(centro, zoom);
    _layer.agendarBusca();
  }

  @override
  void initState() {
    super.initState();
    _layer = PointsLayerController(
      filtros: widget.filtros,
      lerViewport: _lerViewport,
      lerAreas: () => widget.areas.geoJson,
      onTotalChanged: (total) => widget.onTotalChanged?.call(total),
      onZoomMuitoBaixo: (baixo) => widget.onZoomMuitoBaixo?.call(baixo),
    )..munCodes = List.of(widget.municipios);
    _ultimoPedidoFoco = widget.areas.pedidoFoco;
    _ultimaVersaoAreas = widget.areas.versao;
    widget.areas.addListener(_aoMudarAreas);
    _mapEventsSub = mapController.mapEventStream.listen((evento) {
      _centro.value = evento.camera.center;
      // Usuário mexeu no mapa durante a animação da câmera: ele manda.
      if (evento.source != MapEventSource.mapController &&
          _camAnim.isAnimating) {
        _camAnim.stop();
      }
      if (evento is MapEventMoveEnd ||
          evento is MapEventFlingAnimationEnd ||
          evento is MapEventDoubleTapZoomEnd) {
        _layer.agendarBusca();
      } else if (evento is MapEventScrollWheelZoom) {
        _layer.agendarBusca(aguardar: MapConfig.scrollZoomSettle);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PointsMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.areas != oldWidget.areas) {
      oldWidget.areas.removeListener(_aoMudarAreas);
      widget.areas.addListener(_aoMudarAreas);
      _ultimoPedidoFoco = widget.areas.pedidoFoco;
      _ultimaVersaoAreas = widget.areas.versao;
    }
    var mudou = false;
    if (widget.filtros != oldWidget.filtros) {
      _layer.filtros = widget.filtros;
      mudou = true;
    }
    if (!listEquals(widget.municipios, oldWidget.municipios)) {
      _layer.munCodes = List.of(widget.municipios);
      // Cidade nova: carrega as bolhas dela e enquadra a cidade inteira.
      _enquadrarCidades().catchError((_) {});
      return;
    }
    if (mudou) _layer.agendarBusca();
  }

  @override
  void dispose() {
    widget.areas.removeListener(_aoMudarAreas);
    _timerPiscar?.cancel();
    _mapEventsSub?.cancel();
    _camAnim.dispose();
    _layer.dispose();
    _selecao.dispose();
    _centro.dispose();
    _destaque.dispose();
    mapController.dispose();
    super.dispose();
  }

  MapViewport _lerViewport() {
    final camera = mapController.camera;
    final limites = camera.visibleBounds;
    return MapViewport(
      zoom: camera.zoom,
      west: limites.west,
      south: limites.south,
      east: limites.east,
      north: limites.north,
    );
  }

  LatLng _telaParaLatLng(Offset ponto, Size tamanho) =>
      _lerViewport().screenToLatLng(ponto, tamanho);

  void _abrirDetalhe(MapPoint ponto) =>
      PointDetailSheet.mostrar(context, point: ponto);

  void _zoomPorBotao(double passo) {
    final camera = mapController.camera;
    final alvo = (camera.zoom + passo)
        .clamp(MapConfig.minZoom, MapConfig.maxZoom)
        .toDouble();
    if (alvo == camera.zoom) return;
    _animarPara(camera.center, alvo);
  }

  void _aproximarBolha(PointCluster bolha) {
    final alvo = (mapController.camera.zoom + MapConfig.clusterTapZoomStep)
        .clamp(MapConfig.minZoom, MapConfig.maxZoom)
        .toDouble();
    _animarPara(bolha.position, alvo);
  }

  Future<void> _abrir() async {
    try {
      await _enquadrarCidades();
    } catch (_) {
    }
    if (mounted) _layer.agendarBusca();
  }

  Future<void> _enquadrarCidades() async {
    final celulas = await _layer.carregarVisaoGeral();
    if (!mounted) return;
    if (celulas.isEmpty) {
      mapController.move(widget.initialCenter, MapConfig.openZoom);
    } else {
      mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(
            [for (final c in celulas) c.position],
          ),
          padding: const EdgeInsets.all(MapConfig.overviewFitPadding),
          // Fica nas bolhas mesmo numa cidade pequena.
          maxZoom: MapConfig.minZoomToSearch - 0.5,
        ),
      );
    }
    _layer.agendarBusca(); // fitCamera não dispara o fim de movimento
  }

  void _aoMudarAreas() {
    final areas = widget.areas;
    final listaMudou = areas.versao != _ultimaVersaoAreas;
    _ultimaVersaoAreas = areas.versao;

    if (areas.pedidoFoco != _ultimoPedidoFoco) {
      _ultimoPedidoFoco = areas.pedidoFoco;
      final i = areas.areaEmFoco;
      if (i != null) {
        _focarArea(i);
        _layer.agendarBusca(); // fitCamera não dispara MoveEnd
      }
    } else if (listaMudou) {
      _pararPiscar(); // índices podem ter mudado
    }
    if (listaMudou) _layer.agendarBusca(); // recalcula o total das áreas
    if (mounted) setState(() {}); // redesenha áreas e cor dos pontos
  }

  void _focarArea(int i) {
    final lista = widget.areas.areas;
    if (i < 0 || i >= lista.length) return;
    final area = lista[i];
    mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(area.northWest, area.southEast),
        padding: MapStyles.areaFocusPadding,
        maxZoom: MapStyles.areaFocusMaxZoom,
      ),
    );
    _piscar(i);
  }

  void _piscar(int i) {
    _timerPiscar?.cancel();
    var trocas = 0;
    _destaque.value = i;
    _timerPiscar = Timer.periodic(MapStyles.areaBlinkInterval, (_) {
      trocas++;
      if (trocas >= MapStyles.areaBlinkToggles) {
        _pararPiscar();
        return;
      }
      _destaque.value = _destaque.value == null ? i : null;
    });
  }

  void _pararPiscar() {
    _timerPiscar?.cancel();
    _timerPiscar = null;
    _destaque.value = null;
  }

  void _aoTocarMapa(TapPosition _, LatLng ponto) {
    if (_selecionando) return;
    final i = widget.areas.indiceEm(ponto);
    if (i != null) {
      widget.areas.focar(i);
      return;
    }
    widget.areas.selecionar(null);
  }

  void _alternarSelecao() {
    setState(() => _selecionando = !_selecionando);
    _selecao.value = null;
  }

  void _confirmarArea(SelectedArea area) {
    setState(() => _selecionando = false);
    _selecao.value = null;
    widget.areas.adicionar(area);
  }

  Widget _esmaecer({required bool visivel, required Widget child}) {
    return AnimatedOpacity(
      opacity: visivel ? 1.0 : 0.0,
      duration: MapStyles.modeFadeDuration,
      curve: Curves.easeInOut,
      child: IgnorePointer(ignoring: !visivel, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final areas = widget.areas;
    return LayoutBuilder(
      builder: (context, constraints) {
        _tamanhoMapa = Size(constraints.maxWidth, constraints.maxHeight);
        return ListenableBuilder(
          listenable: _layer,
          builder: (context, _) => Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: widget.initialCenter,
                  initialZoom: widget.initialZoom,
                  minZoom: MapConfig.minZoom,
                  maxZoom: MapConfig.maxZoom,
                  onMapReady: _abrir,
                  onTap: _aoTocarMapa,
                  // Rotação desligada: a conversão tela -> coordenada
                  // assume o norte para cima. Selecionando, o mapa congela.
                  interactionOptions: InteractionOptions(
                    flags: _selecionando
                        ? InteractiveFlag.none
                        : InteractiveFlag.all & ~InteractiveFlag.rotate,
                    // Touchpad no navegador: a pinça chega como rolagem, e
                    // o padrão (0.005) responde devagar demais.
                    scrollWheelVelocity: MapConfig.scrollWheelVelocity,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: MapConfig.osmTileUrl,
                    userAgentPackageName: MapConfig.userAgentPackage,
                  ),
                  if (_mostrarRelevo)
                    Opacity(
                      opacity: MapConfig.reliefOpacity,
                      child: TileLayer(
                        urlTemplate: MapConfig.reliefTileUrl,
                        userAgentPackageName: MapConfig.userAgentPackage,
                        maxNativeZoom: MapConfig.reliefMaxNativeZoom,
                      ),
                    ),
                  SelectedAreasLayer(
                    areas: areas.areas,
                    selecionada: areas.selecionada,
                    destaque: _destaque,
                  ),
                  // Bolhas <-> pontos: cada camada esmaece no lugar da outra
                  // (opacidade da camada inteira, não por marcador).
                  _esmaecer(
                    visivel: _layer.agrupado,
                    child: ClusterBubblesLayer(
                      agrupamento: _layer.agrupamento,
                      visivel: _layer.agrupado,
                      onTap: _aproximarBolha,
                    ),
                  ),
                  _esmaecer(
                    visivel: !_layer.agrupado,
                    child: PointMarkersLayer(
                      pontos: _layer.pontos,
                      onTap: _abrirDetalhe,
                      destacado: areas.isEmpty ? null : areas.contemPonto,
                    ),
                  ),
                ],
              ),
              if (_selecionando)
                Positioned.fill(
                  child: AreaSelectionOverlay(
                    selecao: _selecao,
                    telaParaLatLng: _telaParaLatLng,
                    onConfirmar: _confirmarArea,
                  ),
                ),
              if (_layer.carregando && !_layer.carregandoVisaoGeral)
                const Positioned(
                  top: MapStyles.loadingTop,
                  left: 0,
                  right: 0,
                  child: MapLoadingIndicator(),
                ),
              Positioned(
                left: MapStyles.coordsLeft,
                bottom: MapStyles.coordsBottom,
                child: IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MapLegend(agrupado: _layer.agrupado),
                      const SizedBox(height: MapStyles.legendGap),
                      _painelCoordenadas(),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: MapStyles.toolbarRight,
                bottom: MapStyles.toolbarBottom,
                child: MapToolbar(
                  itens: [
                    MapToolbarItem(
                      icon: Icons.add_rounded,
                      tooltip: 'Aproximar',
                      onTap: () => _zoomPorBotao(MapConfig.zoomButtonStep),
                    ),
                    MapToolbarItem(
                      icon: Icons.remove_rounded,
                      tooltip: 'Afastar',
                      onTap: () => _zoomPorBotao(-MapConfig.zoomButtonStep),
                    ),
                    MapToolbarItem(
                      icon: _selecionando
                          ? Icons.close_rounded
                          : Icons.highlight_alt,
                      tooltip: _selecionando
                          ? 'Sair da seleção'
                          : (areas.isEmpty
                              ? 'Selecionar área'
                              : 'Selecionar outra área'),
                      ativo: _selecionando,
                      onTap: _alternarSelecao,
                    ),
                    // Lixeira só com uma área selecionada, e apaga só ela.
                    // Apagar todas fica no "Limpar" do filtro Áreas.
                    if (areas.selecionada != null && !_selecionando)
                      MapToolbarItem(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Apagar Área ${areas.selecionada! + 1}',
                        onTap: areas.removerSelecionada,
                      ),
                    MapToolbarItem(
                      icon: Icons.terrain_outlined,
                      tooltip: 'Relevo (NASA GIBS)',
                      ativo: _mostrarRelevo,
                      onTap: () =>
                          setState(() => _mostrarRelevo = !_mostrarRelevo),
                    ),
                  ],
                ),
              ),
              if (_layer.erro case final erro? when !_layer.carregandoVisaoGeral)
                Positioned(
                  left: MapStyles.zoomHintSideMargin,
                  right: MapStyles.zoomHintSideMargin,
                  bottom: MapStyles.zoomHintBottom,
                  child: Center(
                    child: Container(
                      padding: MapStyles.zoomHintPadding,
                      decoration: MapStyles.zoomHintDecoration,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(erro, style: MapStyles.zoomHintText),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              _layer.limparErro();
                              _layer.agendarBusca();
                            },
                            child: const Text('Tentar de novo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_layer.carregandoVisaoGeral)
                const Positioned.fill(child: MapOverviewLoading()),
            ],
          ),
        );
      },
    );
  }

  Widget _painelCoordenadas() {
    String f(double v) => v.toStringAsFixed(5);

    return ValueListenableBuilder<Rect?>(
      valueListenable: _selecao,
      builder: (context, r, _) {
        if (r != null && r.width > 0 && r.height > 0) {
          final area = SelectedArea.fromCorners(
            _telaParaLatLng(r.topLeft, _tamanhoMapa),
            _telaParaLatLng(r.bottomRight, _tamanhoMapa),
          );
          return MapCoordinatesPanel(
            titulo: 'SELEÇÃO',
            linhas: [
              [('N', f(area.north)), ('S', f(area.south))],
              [('O', f(area.west)), ('L', f(area.east))],
            ],
          );
        }
        return ValueListenableBuilder<LatLng>(
          valueListenable: _centro,
          builder: (context, c, _) => MapCoordinatesPanel(
            titulo: 'CENTRO',
            linhas: [
              [('LAT', f(c.latitude))],
              [('LON', f(c.longitude))],
            ],
          ),
        );
      },
    );
  }
}
