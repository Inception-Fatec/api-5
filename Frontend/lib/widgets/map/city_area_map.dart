import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_theme.dart';
import '../../services/geocoding_service.dart';
import '../../services/ibge_service.dart';
import 'selected_area.dart';

/// Componente único de mapa, usado tanto no formulário de Novo
/// Projeto (interativo) quanto no relatório do projeto (só leitura).
///
/// Componente CONTROLADO: quem guarda a área COMBINADA final é o
/// widget pai (via [area] + [onAreaChanged]) — é isso que vira o
/// `polygon_geojson` do payload. Internamente, porém, o mapa mostra
/// cada cidade/retângulo desenhado como uma peça PRÓPRIA e visível ao
/// mesmo tempo — a área combinada é só a "soma" delas por trás.
///
/// Duas formas de adicionar uma peça (e elas se somam):
///   1. Busca de cidade (IBGE) — geocodificada uma vez, ao adicionar
///   2. Desenho manual de retângulo — arrasta, solta, confirma (✓)
///      ou descarta (✗)
///
/// Tocar num chip (cidade ou área desenhada) faz a peça correspondente
/// piscar no mapa e centraliza a câmera nela.
class CityAreaMap extends StatefulWidget {
  const CityAreaMap({
    super.key,
    required this.area,
    this.cidades = const [],
    this.onAreaChanged,
    this.onCidadesChanged,
    this.somenteLeitura = false,
    this.mostrarToggleRelevo = true,
    this.mostrarDesenhoManual = true,
    this.height = 320,
  });

  /// Área COMBINADA atual — controlada pelo pai. Em [somenteLeitura],
  /// é só isso que é mostrado (um único polígono), já que o
  /// relatório não tem acesso às peças individuais.
  final SelectedArea? area;

  /// Cidades que compõem a área atual — só relevante fora do modo
  /// somente-leitura (ex: pro pai montar `mun_codes` do payload).
  final List<Municipio> cidades;

  final ValueChanged<SelectedArea?>? onAreaChanged;
  final ValueChanged<List<Municipio>>? onCidadesChanged;

  final bool somenteLeitura;
  final bool mostrarToggleRelevo;
  final bool mostrarDesenhoManual;
  final double height;

  @override
  State<CityAreaMap> createState() => _CityAreaMapState();
}

class _CityAreaMapState extends State<CityAreaMap> {
  static const _distanciaCalc = Distance();

  final _ibge = IbgeService();
  final _geocoding = GeocodingService();
  final _buscaController = TextEditingController();
  final _mapController = MapController();

  List<Municipio> _resultadosBusca = [];
  bool _buscandoCidade = false;
  bool _carregandoCidade = false;
  String? _erro;

  // Cada cidade guarda a própria área geocodificada — geocodificada
  // UMA vez, quando adicionada (não recalcula tudo de novo a cada
  // mudança, o que também elimina condição de corrida entre buscas).
  final Map<Municipio, SelectedArea> _areasCidades = {};

  // Retângulos desenhados manualmente e já confirmados.
  final List<SelectedArea> _areasDesenhadas = [];

  // Qual peça está "piscando" no momento (Municipio ou SelectedArea
  // de _areasDesenhadas), e se o pulso está aceso ou apagado agora.
  Object? _pulsandoId;
  bool _pulsoAceso = false;

  // Desenho manual
  bool _desenhandoManualmente = false;
  Offset? _dragStartOffset;
  Offset? _dragCurrentOffset;
  Rect? _retanguloPendente;

  bool _mostrarRelevoNasa = false;
  double _opacidadeRelevo = 0.6;
  bool _mostrarPainelCamadas = false;

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CityAreaMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Só usado pra enquadrar a área combinada quando ela muda vindo
    // de fora (ex: primeira vez que uma peça é adicionada). Depois
    // disso, cada peça tem seu próprio enquadramento ao ser tocada.
    final area = widget.area;
    if (area != null && area != oldWidget.area && _pulsandoId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(LatLng(area.south, area.west), LatLng(area.north, area.east)),
            padding: const EdgeInsets.all(24),
          ),
        );
      });
    }
  }

  // -----------------------------------------------------------------------
  // Busca e adição de cidade
  // -----------------------------------------------------------------------

  Future<void> _buscarCidade(String texto) async {
    if (texto.trim().length < 2) {
      setState(() => _resultadosBusca = []);
      return;
    }
    setState(() {
      _buscandoCidade = true;
      _erro = null;
    });
    try {
      final resultados = await _ibge.buscarPorNome(texto);
      if (!mounted) return;
      setState(() {
        _resultadosBusca = resultados;
        _buscandoCidade = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _buscandoCidade = false;
        _erro = 'Não foi possível buscar cidades agora. Verifique sua conexão.';
      });
    }
  }

  Future<void> _adicionarCidade(Municipio m) async {
    if (_areasCidades.containsKey(m)) return;
    setState(() {
      _resultadosBusca = [];
      _buscaController.clear();
      _carregandoCidade = true;
      _erro = null;
    });

    try {
      final resultados = await _geocoding.buscar('${m.nome}, ${m.uf}, Brasil');
      if (!mounted) return;

      if (resultados.isEmpty) {
        setState(() {
          _carregandoCidade = false;
          _erro = 'Não foi possível localizar ${m.nome} no mapa.';
        });
        return;
      }

      setState(() {
        _areasCidades[m] = resultados.first.area;
        _carregandoCidade = false;
      });
      widget.onCidadesChanged?.call(_areasCidades.keys.toList());
      _emitirAreaCombinada();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregandoCidade = false;
        _erro = 'Não foi possível calcular a área agora. Tente novamente.';
      });
    }
  }

  void _removerCidade(Municipio m) {
    setState(() => _areasCidades.remove(m));
    widget.onCidadesChanged?.call(_areasCidades.keys.toList());
    _emitirAreaCombinada();
  }

  // -----------------------------------------------------------------------
  // Desenho manual — arrasta, solta, confirma ou descarta
  // -----------------------------------------------------------------------

  void _onPanStart(DragStartDetails d) {
    if (!_desenhandoManualmente) return;
    setState(() {
      _dragStartOffset = d.localPosition;
      _dragCurrentOffset = d.localPosition;
      _retanguloPendente = null;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_desenhandoManualmente || _dragStartOffset == null) return;
    setState(() => _dragCurrentOffset = d.localPosition);
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_desenhandoManualmente || _dragStartOffset == null || _dragCurrentOffset == null) return;
    setState(() {
      _retanguloPendente = Rect.fromPoints(_dragStartOffset!, _dragCurrentOffset!);
      _dragStartOffset = null;
      _dragCurrentOffset = null;
    });
  }

  void _confirmarRetangulo() {
    final rect = _retanguloPendente;
    if (rect == null) return;

    final camera = _mapController.camera;
    final p1 = camera.offsetToCrs(rect.topLeft);
    final p2 = camera.offsetToCrs(rect.bottomRight);

    final south = math.min(p1.latitude, p2.latitude);
    final north = math.max(p1.latitude, p2.latitude);
    final west = math.min(p1.longitude, p2.longitude);
    final east = math.max(p1.longitude, p2.longitude);
    final diagonalKm = _distanciaCalc.as(LengthUnit.Kilometer, LatLng(south, west), LatLng(north, east));

    if (diagonalKm < 0.05) {
      setState(() => _retanguloPendente = null);
      return;
    }

    setState(() {
      _areasDesenhadas.add(SelectedArea(south: south, north: north, west: west, east: east, diagonalKm: diagonalKm));
      _retanguloPendente = null;
      _desenhandoManualmente = false;
    });
    _emitirAreaCombinada();
  }

  void _descartarRetangulo() => setState(() => _retanguloPendente = null);

  void _removerAreaDesenhada(SelectedArea a) {
    setState(() => _areasDesenhadas.remove(a));
    _emitirAreaCombinada();
  }

  // -----------------------------------------------------------------------
  // Combinação (bbox que engloba tudo) — é isso que vai pro payload
  // -----------------------------------------------------------------------

  void _emitirAreaCombinada() {
    if (_areasCidades.isEmpty && _areasDesenhadas.isEmpty) {
      widget.onAreaChanged?.call(null);
      return;
    }

    double? south, north, west, east;
    void expandir(SelectedArea a) {
      south = south == null ? a.south : math.min(south!, a.south);
      north = north == null ? a.north : math.max(north!, a.north);
      west = west == null ? a.west : math.min(west!, a.west);
      east = east == null ? a.east : math.max(east!, a.east);
    }

    for (final a in _areasCidades.values) {
      expandir(a);
    }
    for (final a in _areasDesenhadas) {
      expandir(a);
    }

    widget.onAreaChanged?.call(SelectedArea(
      south: south!,
      north: north!,
      west: west!,
      east: east!,
      diagonalKm: _distanciaCalc.as(LengthUnit.Kilometer, LatLng(south!, west!), LatLng(north!, east!)),
      label: [
        ..._areasCidades.keys.map((m) => m.nome),
        if (_areasDesenhadas.isNotEmpty) '${_areasDesenhadas.length} área(s) desenhada(s)',
      ].join(', '),
    ));
  }

  // -----------------------------------------------------------------------
  // Destacar (piscar) uma peça ao tocar no chip correspondente
  // -----------------------------------------------------------------------

  Future<void> _destacar(Object id, SelectedArea area) async {
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(LatLng(area.south, area.west), LatLng(area.north, area.east)),
        padding: const EdgeInsets.all(40),
      ),
    );
    setState(() => _pulsandoId = id);
    for (var i = 0; i < 3; i++) {
      if (!mounted) return;
      setState(() => _pulsoAceso = true);
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() => _pulsoAceso = false);
      await Future.delayed(const Duration(milliseconds: 160));
    }
    if (mounted) setState(() => _pulsandoId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.somenteLeitura) _buildBuscaCidade(),
        if (_erro != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Text(_erro!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
          ),
        if (_carregandoCidade)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        const SizedBox(height: 8),
        _buildMapa(),
      ],
    );
  }

  Widget _buildBuscaCidade() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: _buscaController,
                  onChanged: _buscarCidade,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar cidade (ex: São José dos Campos)',
                    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    prefixIcon: _buscandoCidade
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : const Icon(Icons.search, color: AppColors.textSecondary),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            if (widget.mostrarDesenhoManual) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _desenhandoManualmente = !_desenhandoManualmente),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _desenhandoManualmente ? AppColors.primary : AppColors.inputFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.draw_outlined, color: _desenhandoManualmente ? Colors.white : AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
        if (_desenhandoManualmente)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Modo desenho ativo — arraste no mapa, depois confirme com ✓.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
        if (_resultadosBusca.isNotEmpty)
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
              children: _resultadosBusca
                  .map((m) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_city, size: 18, color: AppColors.textSecondary),
                        title: Text(m.rotulo, style: const TextStyle(fontSize: 13)),
                        onTap: () => _adicionarCidade(m),
                      ))
                  .toList(),
            ),
          ),
        if (_areasCidades.isNotEmpty || _areasDesenhadas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._areasCidades.entries.map((e) => GestureDetector(
                      onTap: () => _destacar(e.key, e.value),
                      child: Chip(
                        label: Text(e.key.rotulo, style: const TextStyle(fontSize: 12)),
                        onDeleted: () => _removerCidade(e.key),
                        backgroundColor: AppColors.chipBg,
                        deleteIconColor: AppColors.textSecondary,
                      ),
                    )),
                ..._areasDesenhadas.asMap().entries.map((e) => GestureDetector(
                      onTap: () => _destacar(e.value, e.value),
                      child: Chip(
                        avatar: const Icon(Icons.draw_outlined, size: 14),
                        label: Text('Área ${e.key + 1}', style: const TextStyle(fontSize: 12)),
                        onDeleted: () => _removerAreaDesenhada(e.value),
                        backgroundColor: AppColors.chipBg,
                        deleteIconColor: AppColors.textSecondary,
                      ),
                    )),
              ],
            ),
          ),
      ],
    );
  }

  List<Polygon> _construirPoligonos() {
    if (widget.somenteLeitura) {
      final area = widget.area;
      if (area == null) return [];
      return [
        Polygon(points: area.corners, color: AppColors.coverageFill, borderColor: AppColors.coverageBorder, borderStrokeWidth: 2),
      ];
    }

    final lista = <Polygon>[];
    _areasCidades.forEach((m, a) {
      final aceso = _pulsandoId == m && _pulsoAceso;
      lista.add(Polygon(
        points: a.corners,
        color: aceso ? AppColors.primary.withOpacity(0.55) : AppColors.coverageFill,
        borderColor: aceso ? AppColors.primary : AppColors.coverageBorder,
        borderStrokeWidth: aceso ? 3 : 2,
      ));
    });
    for (final a in _areasDesenhadas) {
      final aceso = _pulsandoId == a && _pulsoAceso;
      lista.add(Polygon(
        points: a.corners,
        color: aceso ? AppColors.primary.withOpacity(0.55) : AppColors.coverageFill,
        borderColor: aceso ? AppColors.primary : AppColors.coverageBorder,
        borderStrokeWidth: aceso ? 3 : 2,
      ));
    }
    return lista;
  }

  Widget _buildMapa() {
    final area = widget.area;
    final liveRect = (_dragStartOffset != null && _dragCurrentOffset != null)
        ? Rect.fromPoints(_dragStartOffset!, _dragCurrentOffset!)
        : null;

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
              initialCenter: area != null ? LatLng(area.south, area.west) : const LatLng(-14.2350, -51.9253),
              initialZoom: area != null ? 12 : 4,
              initialCameraFit: area != null
                  ? CameraFit.bounds(
                      bounds: LatLngBounds(LatLng(area.south, area.west), LatLng(area.north, area.east)),
                      padding: const EdgeInsets.all(24),
                    )
                  : null,
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
              PolygonLayer(polygons: _construirPoligonos()),
            ],
          ),

          if (widget.mostrarDesenhoManual && !widget.somenteLeitura)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_desenhandoManualmente,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

          if (liveRect != null)
            Positioned.fromRect(
              rect: liveRect,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.coverageFill,
                  border: Border.all(color: AppColors.coverageBorder, width: 2),
                ),
              ),
            ),

          if (_retanguloPendente != null) ...[
            Positioned.fromRect(
              rect: _retanguloPendente!,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.coverageFill.withOpacity(0.5),
                  border: Border.all(color: AppColors.coverageBorder, width: 2),
                ),
              ),
            ),
            Positioned(
              left: _retanguloPendente!.center.dx - 40,
              top: _retanguloPendente!.center.dy - 18,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _botaoConfirmacao(Icons.check, Colors.green, _confirmarRetangulo, tooltip: 'Confirmar área'),
                  const SizedBox(width: 8),
                  _botaoConfirmacao(Icons.close, Colors.redAccent, _descartarRetangulo, tooltip: 'Descartar'),
                ],
              ),
            ),
          ],

          Positioned(
            top: 8,
            right: 8,
            child: Column(
              children: [
                _botaoMapa(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                const SizedBox(height: 6),
                _botaoMapa(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
                if (widget.mostrarToggleRelevo) ...[
                  const SizedBox(height: 6),
                  _botaoMapa(Icons.terrain, () => setState(() => _mostrarPainelCamadas = !_mostrarPainelCamadas)),
                ],
              ],
            ),
          ),

          if (widget.mostrarToggleRelevo && _mostrarPainelCamadas)
            Positioned(
              top: 8,
              right: 52,
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
      ),
    );
  }

  Widget _botaoMapa(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _botaoConfirmacao(IconData icon, Color color, VoidCallback onTap, {required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}