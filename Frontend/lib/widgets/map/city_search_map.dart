import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_theme.dart';
import '../../services/geocoding_service.dart';
import 'selected_area.dart';

/// Mapa com busca de cidade/local — substitui o antigo jeito de
/// selecionar arrastando um retângulo. Você digita um nome de lugar,
/// escolhe um resultado, e a área (bounding box) já vem pronta da
/// própria busca — não precisa desenhar nada na maioria dos casos.
///
/// Ainda existe um modo de desenho manual (retângulo arrastando) como
/// alternativa — útil quando a área que você quer não corresponde a
/// nenhum limite administrativo (ex: um raio ao redor de uma
/// subestação específica) — mas ele fica escondido atrás de um botão,
/// não é mais o método padrão.
class CitySearchMap extends StatefulWidget {
  const CitySearchMap({
    super.key,
    required this.initialCenter,
    this.initialZoom = 12,
    this.height = 320,
    this.onAreaConfirmed,
    this.mostrarToggleRelevo = true,
    this.mostrarDesenhoManual = true,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final double height;

  /// Chamado toda vez que uma área é confirmada — seja por busca de
  /// cidade, seja por desenho manual.
  final ValueChanged<SelectedArea>? onAreaConfirmed;

  /// Mostra o botão de camada de relevo NASA. Desligado na tela de
  /// Novo Projeto (onde o mapa é só pra escolher a área, não pra
  /// explorar visualmente), ligado na tela de Mapa.
  final bool mostrarToggleRelevo;

  /// Mostra o botão de alternar pro modo de desenho manual
  /// (retângulo arrastando), como alternativa à busca.
  final bool mostrarDesenhoManual;

  @override
  State<CitySearchMap> createState() => _CitySearchMapState();
}

class _CitySearchMapState extends State<CitySearchMap> {
  final MapController _mapController = MapController();
  final _geocoding = GeocodingService();
  final _buscaController = TextEditingController();

  List<CitySearchResult> _resultados = [];
  bool _buscando = false;
  Timer? _debounce;

  SelectedArea? _area;

  // Modo de desenho manual (fallback)
  bool _desenhandoManualmente = false;
  Offset? _dragStartOffset;
  Offset? _dragCurrentOffset;
  static const _distanciaCalc = Distance();

  bool _mostrarRelevoNasa = false;
  double _opacidadeRelevo = 0.6;
  bool _mostrarPainelCamadas = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaController.dispose();
    super.dispose();
  }

  void _onBuscaMudou(String texto) {
    _debounce?.cancel();
    if (texto.trim().length < 3) {
      setState(() => _resultados = []);
      return;
    }
    // Debounce de 500ms — evita martelar a Nominatim a cada tecla
    // digitada (a política de uso deles pede no máx. ~1 req/s).
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _buscando = true);
      final resultados = await _geocoding.buscar(texto);
      if (!mounted) return;
      setState(() {
        _resultados = resultados;
        _buscando = false;
      });
    });
  }

  void _selecionarResultado(CitySearchResult resultado) {
    setState(() {
      _area = resultado.area;
      _resultados = [];
      _buscaController.text = resultado.area.label ?? resultado.displayName;
    });
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(resultado.area.south, resultado.area.west),
          LatLng(resultado.area.north, resultado.area.east),
        ),
        padding: const EdgeInsets.all(24),
      ),
    );
    widget.onAreaConfirmed?.call(resultado.area);
    FocusScope.of(context).unfocus();
  }

  // --- Desenho manual (fallback) ------------------------------------

  void _onPanStart(DragStartDetails d) {
    if (!_desenhandoManualmente) return;
    setState(() {
      _dragStartOffset = d.localPosition;
      _dragCurrentOffset = d.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_desenhandoManualmente || _dragStartOffset == null) return;
    setState(() => _dragCurrentOffset = d.localPosition);
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_desenhandoManualmente || _dragStartOffset == null || _dragCurrentOffset == null) return;

    final camera = _mapController.camera;
    final p1 = camera.offsetToCrs(_dragStartOffset!);
    final p2 = camera.offsetToCrs(_dragCurrentOffset!);

    final south = math.min(p1.latitude, p2.latitude);
    final north = math.max(p1.latitude, p2.latitude);
    final west = math.min(p1.longitude, p2.longitude);
    final east = math.max(p1.longitude, p2.longitude);
    final diagonalKm = _distanciaCalc.as(LengthUnit.Kilometer, LatLng(south, west), LatLng(north, east));

    setState(() {
      _dragStartOffset = null;
      _dragCurrentOffset = null;
    });

    if (diagonalKm < 0.05) return;

    final area = SelectedArea(south: south, north: north, west: west, east: east, diagonalKm: diagonalKm);
    setState(() {
      _area = area;
      _buscaController.text = '';
    });
    widget.onAreaConfirmed?.call(area);
  }

  Future<void> _copiar(SelectedArea area) async {
    await Clipboard.setData(ClipboardData(
      text: 'south: ${area.south}, north: ${area.north}, west: ${area.west}, east: ${area.east}',
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coordenadas copiadas!'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBarraDeBusca(),
        const SizedBox(height: 8),
        _buildMapa(),
      ],
    );
  }

  Widget _buildBarraDeBusca() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: _buscaController,
            onChanged: _onBuscaMudou,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar cidade ou local (ex: São José dos Campos)',
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              prefixIcon: _buscando
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: widget.mostrarDesenhoManual
                  ? IconButton(
                      tooltip: 'Desenhar área manualmente',
                      icon: Icon(
                        Icons.draw_outlined,
                        color: _desenhandoManualmente ? AppColors.primary : AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _desenhandoManualmente = !_desenhandoManualmente),
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        if (_resultados.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E8EF)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _resultados
                  .map((r) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textSecondary),
                        title: Text(r.displayName, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _selecionarResultado(r),
                      ))
                  .toList(),
            ),
          ),
        if (_desenhandoManualmente)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Modo desenho manual ativo — arraste no mapa pra definir a área.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _buildMapa() {
    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: widget.initialZoom,
              minZoom: 3,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.tecsys.app',
              ),
              if (_mostrarRelevoNasa)
                Opacity(
                  opacity: _opacidadeRelevo,
                  child: TileLayer(
                    urlTemplate:
                        'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/'
                        'ASTER_GDEM_Greyscale_Shaded_Relief/default/'
                        'GoogleMapsCompatible_Level12/{z}/{y}/{x}.png',
                    tileProvider: NetworkTileProvider(),
                    maxNativeZoom: 12,
                    maxZoom: 22,
                  ),
                ),
              if (_area != null)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _area!.corners,
                      color: AppColors.coverageFill,
                      borderColor: AppColors.coverageBorder,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
            ],
          ),

          if (widget.mostrarDesenhoManual)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_desenhandoManualmente,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: (_dragStartOffset != null && _dragCurrentOffset != null)
                      ? Positioned.fromRect(
                          rect: Rect.fromPoints(_dragStartOffset!, _dragCurrentOffset!),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.coverageFill,
                              border: Border.all(color: AppColors.coverageBorder, width: 2),
                            ),
                          ),
                        )
                      : Container(color: Colors.transparent),
                ),
              ),
            ),

          if (_area != null)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _area!.label ??
                            '${_area!.south.toStringAsFixed(4)}, ${_area!.west.toStringAsFixed(4)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _copiar(_area!),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.copy, size: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (widget.mostrarToggleRelevo) ...[
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: () => setState(() => _mostrarPainelCamadas = !_mostrarPainelCamadas),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                  ),
                  child: const Icon(Icons.terrain, size: 16, color: AppColors.textPrimary),
                ),
              ),
            ),
            if (_mostrarPainelCamadas)
              Positioned(
                top: 44,
                right: 8,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Relevo NASA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Switch(value: _mostrarRelevoNasa, onChanged: (v) => setState(() => _mostrarRelevoNasa = v)),
                          ],
                        ),
                        if (_mostrarRelevoNasa)
                          SizedBox(
                            width: 140,
                            child: Slider(
                              value: _opacidadeRelevo,
                              min: 0.1,
                              max: 1.0,
                              divisions: 9,
                              onChanged: (v) => setState(() => _opacidadeRelevo = v),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}