import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/points_filter_service.dart';
import '../../theme/app_theme.dart';
import 'filtros_pontos.dart';
import 'point_detail_sheet.dart';

class PointsMapView extends StatefulWidget {
  const PointsMapView({
    super.key,
    required this.filtros,
    required this.initialCenter,
    this.initialZoom = 12,
    this.onTotalChanged,
    this.onZoomMuitoBaixo,
    this.onCentroidChanged,
  });

  final FiltrosPontos filtros;
  final LatLng initialCenter;
  final double initialZoom;
  final ValueChanged<int>? onTotalChanged;

  final ValueChanged<bool>? onZoomMuitoBaixo;

  final ValueChanged<LatLng?>? onCentroidChanged;

  @override
  State<PointsMapView> createState() => PointsMapViewState();
}

class PointsMapViewState extends State<PointsMapView> {
  final MapController mapController = MapController();
  final _service = PointsFilterService();

  void buscarNovamente() => _agendarBusca();

  Timer? _debounce;
  StreamSubscription<MapEvent>? _mapEventsSub;
  int _pedidoId = 0;
  List<Map<String, dynamic>> _features = [];
  List<(Map<String, dynamic>, LatLng)> _pontosRenderizaveis = [];
  bool _carregando = false;

  bool _mostrarRelevo = false;
  static const int _teto = 800;

  static const double _zoomMinimoPraBuscar = 13;

  @override
  void initState() {
    super.initState();
    _mapEventsSub = mapController.mapEventStream.listen((evt) {
      if (evt is MapEventMoveEnd || evt is MapEventFlingAnimationEnd || evt is MapEventDoubleTapZoomEnd) {
        _agendarBusca();
      }
    });
  }

  void _aoMapaPronto() {
    _agendarBusca();
  }

  @override
  void didUpdateWidget(covariant PointsMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filtros != oldWidget.filtros) {
      _agendarBusca();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapEventsSub?.cancel();
    mapController.dispose();
    super.dispose();
  }

  void _agendarBusca() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _buscarAgora);
  }

  Future<void> _buscarAgora() async {
    final zoom = mapController.camera.zoom;
    if (zoom < _zoomMinimoPraBuscar) {
      setState(() {
        _features = [];
        _pontosRenderizaveis = [];
        _carregando = false;
      });
      widget.onZoomMuitoBaixo?.call(true);
      widget.onTotalChanged?.call(0);
      return;
    }
    widget.onZoomMuitoBaixo?.call(false);
    final poligono = _bboxParaGeoJson(mapController.camera.visibleBounds);

    final meuPedido = ++_pedidoId;
    setState(() => _carregando = true);

    try {
      final resultado = await _service.buscarPontos(
        distCodes: [widget.filtros.distCode],
        polygonGeoJson: poligono,
        targetLayers: widget.filtros.targetLayers,
        conjCodes: widget.filtros.conjCodes,
        subCodes: widget.filtros.subCodes,
        clasSub: widget.filtros.clasSub,
        cnaeCodes: widget.filtros.cnaeCodes,
        bairroNames: widget.filtros.bairroNames,
      );
      if (!mounted || meuPedido != _pedidoId) return; // resposta desatualizada, descarta
      final novasFeatures = resultado.features.take(_teto).toList();
      final novosPontos = <(Map<String, dynamic>, LatLng)>[
        for (final f in novasFeatures)
          if (_pontoRepresentativo(f['geometry'] as Map<String, dynamic>? ?? const {}) case final p?) (f, p),
      ];
      setState(() {
        _features = novasFeatures;
        _carregando = false;
      });
      widget.onTotalChanged?.call(resultado.totalPoints);
      widget.onCentroidChanged?.call(_calcularCentroideDe(novosPontos));
      await _revelarEmLotes(novosPontos, meuPedido);
    } catch (_) {
      if (!mounted || meuPedido != _pedidoId) return;
      setState(() => _carregando = false);
    }
  }

  static const int _tamanhoLote = 5;

  String? _idDe(Map<String, dynamic> feature) => (feature['properties'] as Map<String, dynamic>?)?['id']?.toString();

  Set<String> _idsDe(List<(Map<String, dynamic>, LatLng)> lista) =>
      lista.map((t) => _idDe(t.$1)).whereType<String>().toSet();

  Future<void> _revelarEmLotes(List<(Map<String, dynamic>, LatLng)> todos, int meuPedido) async {
    final jaMostrando = _idsDe(_pontosRenderizaveis);
    final novos = todos.where((t) {
      final id = _idDe(t.$1);
      return id == null || !jaMostrando.contains(id);
    }).toList();

    final acumulado = List<(Map<String, dynamic>, LatLng)>.of(_pontosRenderizaveis);
    for (var i = 0; i < novos.length; i += _tamanhoLote) {
      if (!mounted || meuPedido != _pedidoId) return; // uma busca mais nova já chegou, descarta
      final fim = (i + _tamanhoLote < novos.length) ? i + _tamanhoLote : novos.length;
      acumulado.addAll(novos.sublist(i, fim));
      setState(() => _pontosRenderizaveis = List.of(acumulado));
      await Future.delayed(const Duration(milliseconds: 16)); // ~1 frame de respiro
    }

    if (!mounted || meuPedido != _pedidoId) return;
    final idsAtuais = _idsDe(todos);
    setState(() {
      _pontosRenderizaveis = _pontosRenderizaveis.where((t) {
        final id = _idDe(t.$1);
        return id == null || idsAtuais.contains(id);
      }).toList();
    });
  }

  LatLng? _calcularCentroideDe(List<(Map<String, dynamic>, LatLng)> pontos) {
    if (pontos.isEmpty) return null;
    var somaLat = 0.0, somaLon = 0.0;
    for (final (_, p) in pontos) {
      somaLat += p.latitude;
      somaLon += p.longitude;
    }
    final n = pontos.length;
    return LatLng(somaLat / n, somaLon / n);
  }

  Map<String, dynamic> _bboxParaGeoJson(LatLngBounds b) {
    return {
      'type': 'Polygon',
      'coordinates': [
        [
          [b.west, b.south],
          [b.east, b.south],
          [b.east, b.north],
          [b.west, b.north],
          [b.west, b.south],
        ]
      ],
    };
  }

  LatLng? _pontoRepresentativo(Map<String, dynamic> geom) {
    final tipo = geom['type'];
    if (tipo == 'Point') {
      final c = geom['coordinates'] as List?;
      if (c == null || c.length < 2) return null;
      return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
    }
    List? vertices;
    if (tipo == 'Polygon') {
      final aneis = geom['coordinates'] as List?;
      vertices = (aneis != null && aneis.isNotEmpty) ? aneis.first as List? : null;
    } else if (tipo == 'MultiPolygon') {
      final polis = geom['coordinates'] as List?;
      final primeiro = (polis != null && polis.isNotEmpty) ? polis.first as List? : null;
      vertices = (primeiro != null && primeiro.isNotEmpty) ? primeiro.first as List? : null;
    } else if (tipo == 'LineString') {
      vertices = geom['coordinates'] as List?;
    } else if (tipo == 'MultiLineString') {
      final linhas = geom['coordinates'] as List?;
      vertices = (linhas != null && linhas.isNotEmpty) ? linhas.first as List? : null;
    }
    if (vertices == null || vertices.isEmpty) return null;
    var somaLat = 0.0, somaLon = 0.0;
    var n = 0;
    for (final v in vertices) {
      final p = v as List;
      somaLon += (p[0] as num).toDouble();
      somaLat += (p[1] as num).toDouble();
      n++;
    }
    return n == 0 ? null : LatLng(somaLat / n, somaLon / n);
  }

  Color _corPorCamada(String? layer) {
    switch (layer) {
      case 'ALTO':
        return Colors.deepOrange;
      case 'MEDIO':
        return Colors.amber.shade700;
      case 'BAIXO':
        return AppColors.infoBlue;
      case 'SUB':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }

  void _abrirDetalhe(Map<String, dynamic> feature) {
    PointDetailSheet.mostrar(context, feature: feature);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            minZoom: 3,
            maxZoom: 19,
            onMapReady: _aoMapaPronto,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.tecsys.frontend_tecsys',
            ),
            if (_mostrarRelevo)
              Opacity(
                opacity: 0.6,
                child: TileLayer(
                  urlTemplate:
                      'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/ASTER_GDEM_Greyscale_Shaded_Relief/default/GoogleMapsCompatible_Level12/{z}/{y}/{x}.jpg',
                  userAgentPackageName: 'com.tecsys.frontend_tecsys',
                  maxNativeZoom: 12,
                ),
              ),
            MarkerLayer(
              markers: [
                for (final (f, p) in _pontosRenderizaveis)
                  Marker(
                    point: p,
                    width: 14,
                    height: 14,
                    child: GestureDetector(
                      onTap: () => _abrirDetalhe(f),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _corPorCamada((f['properties'] as Map<String, dynamic>?)?['layer'] as String?),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (_carregando)
          const Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        Positioned(
          right: 8,
          bottom: 100,
          child: _botaoFlutuante(
            icon: Icons.terrain,
            ativo: _mostrarRelevo,
            tooltip: 'Relevo (NASA GIBS)',
            onTap: () => setState(() => _mostrarRelevo = !_mostrarRelevo),
          ),
        ),
      ],
    );
  }

  Widget _botaoFlutuante({required IconData icon, required VoidCallback onTap, String? tooltip, bool ativo = false}) {
    final botao = Material(
      color: ativo ? AppColors.primary : Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: ativo ? Colors.white : AppColors.textPrimary),
        ),
      ),
    );
    return tooltip == null ? botao : Tooltip(message: tooltip, child: botao);
  }
}