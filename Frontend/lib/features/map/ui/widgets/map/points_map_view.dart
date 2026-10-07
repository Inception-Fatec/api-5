import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:tecsys_app/features/map/data/constants/map_config.dart';
import 'package:tecsys_app/features/map/data/models/filtros_pontos.dart';
import 'package:tecsys_app/features/map/data/models/map_point.dart';
import 'package:tecsys_app/features/map/data/models/map_viewport.dart';
import 'package:tecsys_app/features/map/state/points_layer_controller.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/map_floating_button.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/map_loading_indicator.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/point_detail_sheet.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/point_markers_layer.dart';

/// Mapa com os pontos da área visível. Refaz a busca (via
/// [PointsLayerController]) quando o usuário move o mapa ou os
/// [filtros] mudam.
class PointsMapView extends StatefulWidget {
  final FiltrosPontos filtros;
  final LatLng initialCenter;
  final double initialZoom;
  final ValueChanged<int>? onTotalChanged;
  final ValueChanged<bool>? onZoomMuitoBaixo;

  const PointsMapView({
    super.key,
    required this.filtros,
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
      onTotalChanged: (total) => widget.onTotalChanged?.call(total),
      onZoomMuitoBaixo: (baixo) => widget.onZoomMuitoBaixo?.call(baixo),
    );
    _mapEventsSub = mapController.mapEventStream.listen((evento) {
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
    if (widget.filtros != oldWidget.filtros) {
      _layer.filtros = widget.filtros;
      _layer.agendarBusca();
    }
  }

  @override
  void dispose() {
    _mapEventsSub?.cancel();
    _layer.dispose();
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

  void _abrirDetalhe(MapPoint ponto) =>
      PointDetailSheet.mostrar(context, point: ponto);

  @override
  Widget build(BuildContext context) {
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
              PointMarkersLayer(pontos: _layer.pontos, onTap: _abrirDetalhe),
            ],
          ),
          if (_layer.carregando)
            const Positioned(
              top: MapStyles.loadingTop,
              left: 0,
              right: 0,
              child: MapLoadingIndicator(),
            ),
          Positioned(
            right: MapStyles.floatingRight,
            bottom: MapStyles.floatingBottom,
            child: MapFloatingButton(
              icon: Icons.terrain,
              ativo: _mostrarRelevo,
              tooltip: 'Relevo (NASA GIBS)',
              onTap: () => setState(() => _mostrarRelevo = !_mostrarRelevo),
            ),
          ),
        ],
      ),
    );
  }
}
