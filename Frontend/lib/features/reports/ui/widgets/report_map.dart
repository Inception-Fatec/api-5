import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:tecsys_app/features/map/data/constants/map_config.dart';
import 'package:tecsys_app/features/map/data/constants/map_regions.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/state/report_controller.dart';
import 'package:tecsys_app/features/reports/ui/report_formatters.dart';
import 'package:tecsys_app/features/reports/ui/report_texts.dart';
import 'package:tecsys_app/features/reports/ui/styles/report_styles.dart';
import 'package:tecsys_app/features/reports/ui/widgets/points_layer.dart';

/// Mapa do relatório no estilo da referência do cliente: mancha de
/// cobertura contínua, pins dos gateways propostos e os pontos
/// atendidos/descobertos.
class ReportMap extends StatefulWidget {
  const ReportMap({
    super.key,
    required this.report,
    this.controller,
    this.interactive = true,
    this.fitPadding = ReportStyles.mapFitPadding,
    this.initialFocus,
    this.gatewayMarkers = GatewayMarkerMode.auto,
  });

  final CoverageReport report;

  /// Quando informado, o mapa centraliza no gateway que o controller
  /// pedir (layout largo, onde mapa e lista ficam lado a lado).
  final ReportController? controller;

  /// false = miniatura: sem gestos, só mostra a mancha.
  final bool interactive;
  final EdgeInsets fitPadding;

  /// Abre já centralizado neste gateway (em vez de enquadrar tudo).
  final ReportGateway? initialFocus;

  /// Como mostrar os gateways: por zoom (padrão), só pontos ou nenhum.
  final GatewayMarkerMode gatewayMarkers;

  @override
  State<ReportMap> createState() => _ReportMapState();
}

class _ReportMapState extends State<ReportMap> {
  final MapController _mapController = MapController();
  late int _lastFocusVersion;
  late double _stainRadiusM;

  @override
  void initState() {
    super.initState();
    _lastFocusVersion = widget.controller?.focusVersion ?? 0;
    widget.controller?.addListener(_onControllerChanged);
    _stainRadiusM = _computeStainRadius();
  }

  double _computeStainRadius() => ReportStyles.stainRadiusFor(
      widget.report.coveredPoints.typicalSpacingMeters);

  @override
  void didUpdateWidget(covariant ReportMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.report, widget.report)) {
      _stainRadiusM = _computeStainRadius();
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      _lastFocusVersion = widget.controller?.focusVersion ?? 0;
      widget.controller?.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _mapController.dispose();
    super.dispose();
  }

  /// Toque num gateway da lista: centraliza o mapa nele.
  void _onControllerChanged() {
    final controller = widget.controller;
    if (controller == null || controller.focusVersion == _lastFocusVersion) return;
    _lastFocusVersion = controller.focusVersion;
    final gateway = controller.focusedGateway;
    if (gateway == null) return;
    final zoom = math.max(_mapController.camera.zoom, ReportStyles.focusZoom);
    _mapController.move(gateway.position, zoom);
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(
        camera.center, clampZoom(camera.zoom + delta));
  }

  @override
  Widget build(BuildContext context) {
    final map = _buildMap();
    if (!widget.interactive) return map;
    // Botões de zoom: garantem o zoom mesmo sem roda do mouse/pinça
    // (emulador, desktop, acessibilidade).
    return Stack(
      children: [
        Positioned.fill(child: map),
        Positioned(
          right: 12,
          top: 0,
          bottom: 0,
          child: Center(
            child: _ZoomButtons(
              onZoomIn: () => _zoomBy(1),
              onZoomOut: () => _zoomBy(-1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMap() {
    final report = widget.report;
    final focus = widget.initialFocus;
    final bounds = focus == null ? report.focusBounds : null;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        // Sem limites (nada a enquadrar): cai na região com dados.
        initialCenter: focus?.position ?? MapRegions.centroSaoJoseDosCampos,
        initialZoom:
            focus == null ? ReportStyles.fallbackZoom : ReportStyles.focusZoom,
        initialCameraFit: bounds == null
            ? null
            : CameraFit.bounds(
                bounds: bounds,
                padding: widget.fitPadding,
                maxZoom: MapConfig.maxZoom,
              ),
        minZoom: MapConfig.minZoom,
        maxZoom: MapConfig.maxZoom,
        // Rotação desligada: o PointsLayer assume o norte para cima. O resto
        // (arrastar, pinça, duplo toque e roda do mouse) fica ligado.
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
          // Mesma sensibilidade da roda do mouse do mapa principal do app.
          scrollWheelVelocity: MapConfig.scrollWheelVelocity,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.osmTileUrl,
          userAgentPackageName: MapConfig.userAgentPackage,
        ),
        // A mancha é desenhada pelo PointsLayer, a partir dos pontos
        // realmente atendidos (sem círculo de alcance).
        PointsLayer(
          covered: report.coveredPoints,
          uncovered: report.uncoveredPoints,
          stainRadiusM: _stainRadiusM,
        ),
        if (widget.gatewayMarkers != GatewayMarkerMode.hidden)
          GatewayMarkersLayer(
              gateways: report.gateways, mode: widget.gatewayMarkers),
        // Atribuição do OSM é obrigatória (licença dos tiles): em texto
        // pequeno, sem os ícones (logo do flutter_map e botão "i").
        const SimpleAttributionWidget(
          source: Text(
            '© OpenStreetMap contributors',
            style: TextStyle(fontSize: 10, color: Color(0xFF3C4350)),
          ),
          backgroundColor: Color(0xCCFFFFFF),
        ),
      ],
    );
  }
}

/// Zoom dentro dos limites do mapa.
double clampZoom(double zoom) =>
    zoom.clamp(MapConfig.minZoom, MapConfig.maxZoom).toDouble();

/// Botões + e − sobre o mapa.
class _ZoomButtons extends StatelessWidget {
  const _ZoomButtons({required this.onZoomIn, required this.onZoomOut});

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Aproximar',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.add),
            onPressed: onZoomIn,
          ),
          const SizedBox(
              width: 32, child: Divider(height: 1, color: Color(0xFFE4E8EF))),
          IconButton(
            tooltip: 'Afastar',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.remove),
            onPressed: onZoomOut,
          ),
        ],
      ),
    );
  }
}

/// Como os gateways aparecem no mapa.
enum GatewayMarkerMode {
  /// Bolinha ao longe e pin numerado de perto (padrão).
  auto,

  /// Sempre bolinhas.
  dotsOnly,

  /// Sempre pins simples, sem número (usado na foto do PDF).
  pins,

  /// Nenhum marcador (miniatura do relatório).
  hidden,
}

/// Forma do marcador do gateway conforme o zoom: com 100+ gateways, pins
/// se sobrepõem ao longe, então ficam só bolinhas até chegar perto.
enum GatewayMarkerStyle {
  dot,
  pin,
  numberedPin;

  static GatewayMarkerStyle forZoom(double zoom) =>
      zoom < ReportStyles.markerNumberedMinZoom
          ? GatewayMarkerStyle.dot
          : GatewayMarkerStyle.numberedPin;
}

/// Marcadores dos gateways; relê o zoom da câmera para trocar o estilo.
class GatewayMarkersLayer extends StatelessWidget {
  const GatewayMarkersLayer({
    super.key,
    required this.gateways,
    this.mode = GatewayMarkerMode.auto,
  });

  final List<ReportGateway> gateways;
  final GatewayMarkerMode mode;

  @override
  Widget build(BuildContext context) {
    final style = switch (mode) {
      GatewayMarkerMode.dotsOnly => GatewayMarkerStyle.dot,
      GatewayMarkerMode.pins => GatewayMarkerStyle.pin,
      _ => GatewayMarkerStyle.forZoom(MapCamera.of(context).zoom),
    };
    final isDot = style == GatewayMarkerStyle.dot;
    final isPin = style == GatewayMarkerStyle.pin;
    return MarkerLayer(
      markers: [
        for (final g in gateways)
          Marker(
            point: g.position,
            width: isDot
                ? ReportStyles.markerDotSize
                : isPin
                    ? ReportStyles.markerSmallPinSize
                    : ReportStyles.pinWidth,
            height: isDot
                ? ReportStyles.markerDotSize
                : isPin
                    ? ReportStyles.markerSmallPinSize
                    : ReportStyles.pinHeight,
            alignment: isDot ? Alignment.center : Alignment.topCenter,
            child: _GatewayMarker(gateway: g, style: style),
          ),
      ],
    );
  }
}

class _GatewayMarker extends StatelessWidget {
  const _GatewayMarker({required this.gateway, required this.style});

  final ReportGateway gateway;
  final GatewayMarkerStyle style;

  @override
  Widget build(BuildContext context) {
    final label = 'Gateway ${gateway.order} — '
        '${gatewayTypeLabel(gateway.type)} ${gateway.id} — '
        '${formatInt(gateway.newPointsCovered)} pontos novos';
    final Widget visual = style == GatewayMarkerStyle.dot
        ? Container(
            decoration: BoxDecoration(
              color: ReportStyles.pinColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          )
        : style == GatewayMarkerStyle.pin
            ? const Icon(Icons.location_on,
                size: ReportStyles.markerSmallPinSize,
                color: ReportStyles.pinColor)
            : Stack(
            alignment: Alignment.topCenter,
            children: [
              const Icon(Icons.location_on,
                  size: ReportStyles.pinIconSize,
                  color: ReportStyles.pinColor),
              Positioned(
                top: ReportStyles.pinNumberTop,
                child: Text('${gateway.order}',
                    style: ReportStyles.pinNumberStyle),
              ),
            ],
          );
    return Tooltip(
      message: label,
      child: Semantics(label: label, child: visual),
    );
  }
}
