import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:tecsys_app/features/map/data/constants/map_config.dart';
import 'package:tecsys_app/features/map/data/models/filtros_pontos.dart';
import 'package:tecsys_app/features/map/data/models/map_point.dart';
import 'package:tecsys_app/features/map/data/models/map_viewport.dart';
import 'package:tecsys_app/features/map/data/models/selected_area.dart';
import 'package:tecsys_app/features/map/state/map_areas_controller.dart';
import 'package:tecsys_app/features/map/state/points_layer_controller.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/area_selection_overlay.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/map_coordinates_panel.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/map_legend.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/map_loading_indicator.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/map_toolbar.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/point_detail_sheet.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/point_markers_layer.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/selected_areas_layer.dart';

class PointsMapView extends StatefulWidget {
  final FiltrosPontos filtros;
  final MapAreasController areas;
  final LatLng initialCenter;
  final double initialZoom;
  final ValueChanged<int>? onTotalChanged;
  final ValueChanged<bool>? onZoomMuitoBaixo;

  const PointsMapView({
    super.key,
    required this.filtros,
    required this.areas,
    required this.initialCenter,
    this.initialZoom = MapConfig.defaultZoom,
    this.onTotalChanged,
    this.onZoomMuitoBaixo,
  });

  @override
  State<PointsMapView> createState() => PointsMapViewState();
}

class PointsMapViewState extends State<PointsMapView> {
  final MapController mapController = MapController();
  late final PointsLayerController _layer;
  StreamSubscription<MapEvent>? _mapEventsSub;

  bool _mostrarRelevo = false;
  bool _selecionando = false;

  /// Retângulo sendo arrastado, em coordenadas de tela.
  final _selecao = ValueNotifier<Rect?>(null);

  /// Centro do mapa, para o painel de coordenadas.
  late final _centro = ValueNotifier<LatLng>(widget.initialCenter);

  /// Área piscando no momento (índice), ou null.
  final _destaque = ValueNotifier<int?>(null);
  Timer? _timerPiscar;
  late int _ultimoPedidoFoco;
  late int _ultimaVersaoAreas;

  Size _tamanhoMapa = Size.zero;

  /// Leva o mapa até [centro] e refaz a busca de pontos ali.
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
    );
    _ultimoPedidoFoco = widget.areas.pedidoFoco;
    _ultimaVersaoAreas = widget.areas.versao;
    widget.areas.addListener(_aoMudarAreas);
    _mapEventsSub = mapController.mapEventStream.listen((evento) {
      _centro.value = evento.camera.center;
      if (evento is MapEventMoveEnd ||
          evento is MapEventFlingAnimationEnd ||
          evento is MapEventDoubleTapZoomEnd) {
        _layer.agendarBusca();
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
    if (widget.filtros != oldWidget.filtros) {
      _layer.filtros = widget.filtros;
      _layer.agendarBusca();
    }
  }

  @override
  void dispose() {
    widget.areas.removeListener(_aoMudarAreas);
    _timerPiscar?.cancel();
    _mapEventsSub?.cancel();
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
    } else {
      widget.areas.selecionar(null);
    }
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
                  onMapReady: _layer.agendarBusca,
                  onTap: _aoTocarMapa,
                  // Rotação desligada: a conversão tela -> coordenada
                  // assume o norte para cima. Selecionando, o mapa congela.
                  interactionOptions: InteractionOptions(
                    flags: _selecionando
                        ? InteractiveFlag.none
                        : InteractiveFlag.all & ~InteractiveFlag.rotate,
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
                  PointMarkersLayer(
                    pontos: _layer.pontos,
                    onTap: _abrirDetalhe,
                    destacado: areas.isEmpty ? null : areas.contemPonto,
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
              if (_layer.carregando)
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
                      const MapLegend(),
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