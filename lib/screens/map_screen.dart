import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../widgets/common/app_footer.dart';
import '../widgets/common/page_body.dart';

/// Bounding box já pronto no formato que o OpenTopography espera
/// (south/north/west/east), junto com a diagonal aproximada em km.
class SelectedArea {
  final double south;
  final double north;
  final double west;
  final double east;
  final double diagonalKm;

  const SelectedArea({
    required this.south,
    required this.north,
    required this.west,
    required this.east,
    required this.diagonalKm,
  });

  /// Os 4 cantos, na ordem certa pra desenhar o [Polygon] no
  /// flutter_map (fecha o retângulo).
  List<LatLng> get corners => [
        LatLng(north, west),
        LatLng(north, east),
        LatLng(south, east),
        LatLng(south, west),
      ];
}

/// Map screen — mobile layout unchanged (header, active-project card,
/// map, topology overview, bottom nav). Acima de [_webBreakpoint] a
/// tela troca para um layout de dashboard web: navbar superior,
/// breadcrumb, legenda do mapa e cards de métrica em linha.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _webBreakpoint = 900.0;

  // FATEC São José dos Campos
  static const _gatewayPosition = LatLng(-23.16236, -45.79553);
  static const _sensorPositions = [
    LatLng(-23.16166, -45.79423), // SN-102
    LatLng(-23.16306, -45.79703), // SN-088
    LatLng(-23.16366, -45.79513), // SN-094
  ];
  static const _sensorLabels = ['SN-102', 'SN-088', 'SN-094'];

  final MapController _mapController = MapController();

  // Seleção de área (retângulo arrastável) — precisa do switch
  // ligado pra não brigar com o gesto de mover o mapa 
  static const _distanciaCalc = Distance();
  // 5km era alto demais: em zooms próximos (nível de rua/bairro), um
  // arraste normal cobre só algumas centenas de metros e sempre caía
  // no aviso de "área muito pequena" — por isso nunca preenchia nada.
  static const _minDiagonalKm = 0.05; // só evita clique sem arrastar
  static const _maxDiagonalKm = 700.0; // ~ cobre até 1-2 estados médios

  bool _selecionandoArea = false;
  Offset? _dragStartOffset;
  Offset? _dragCurrentOffset;
  SelectedArea? _areaSelecionada; // área ATIVA (mostrada no badge + no mapa)
  SelectedArea? _ultimaAreaSalva; // fica guardada mesmo quando a ativa some

  // --- Camada de relevo NASA GIBS ----------------------------------------
  bool _mostrarRelevoNasa = false;
  double _opacidadeRelevo = 0.6;

  // --- Painel de camadas (só relevo agora) -------------------------------
  bool _mostrarPainelCamadas = false;

  /// Approximates a dashed line: several short Polyline segments with
  /// gaps between the gateway and a sensor (flutter_map's Polyline has
  /// no built-in dash pattern).
  List<Polyline> _dashedLine(LatLng a, LatLng b) {
    const segments = 10;
    final segs = <Polyline>[];
    for (var i = 0; i < segments; i += 2) {
      final t0 = i / segments;
      final t1 = (i + 1) / segments;
      segs.add(Polyline(
        points: [
          LatLng(a.latitude + (b.latitude - a.latitude) * t0,
              a.longitude + (b.longitude - a.longitude) * t0),
          LatLng(a.latitude + (b.latitude - a.latitude) * t1,
              a.longitude + (b.longitude - a.longitude) * t1),
        ],
        color: AppColors.primary,
        strokeWidth: 2,
      ));
    }
    return segs;
  }

  // -----------------------------------------------------------------------
  // Seleção de área — só captura o arraste quando _selecionandoArea = true;
  // caso contrário o gesto passa direto pro mapa (pan normal).
  // -----------------------------------------------------------------------

  void _onAreaPanStart(DragStartDetails details) {
    if (!_selecionandoArea) return;
    setState(() {
      _dragStartOffset = details.localPosition;
      _dragCurrentOffset = details.localPosition;
    });
  }

  void _onAreaPanUpdate(DragUpdateDetails details) {
    if (!_selecionandoArea || _dragStartOffset == null) return;
    setState(() => _dragCurrentOffset = details.localPosition);
  }

  void _onAreaPanEnd(DragEndDetails details) {
    if (!_selecionandoArea || _dragStartOffset == null || _dragCurrentOffset == null) {
      return;
    }

    final camera = _mapController.camera;
    final p1 = camera.offsetToCrs(_dragStartOffset!);
    final p2 = camera.offsetToCrs(_dragCurrentOffset!);

    final south = math.min(p1.latitude, p2.latitude);
    final north = math.max(p1.latitude, p2.latitude);
    final west = math.min(p1.longitude, p2.longitude);
    final east = math.max(p1.longitude, p2.longitude);

    final diagonalKm = _distanciaCalc.as(
      LengthUnit.Kilometer,
      LatLng(south, west),
      LatLng(north, east),
    );

    setState(() {
      _dragStartOffset = null;
      _dragCurrentOffset = null;
    });

    // debug — confirma no terminal que a coordenada foi capturada
    debugPrint(
        'Área arrastada: S=$south N=$north W=$west E=$east (~${diagonalKm.toStringAsFixed(2)} km)');

    if (diagonalKm < _minDiagonalKm) {
      _avisarArea(
          'Área muito pequena — arraste um retângulo maior (mínimo ~${_minDiagonalKm.toStringAsFixed(0)} km).');
      return;
    }

    if (diagonalKm > _maxDiagonalKm) {
      _avisarArea(
          'Área muito grande (${diagonalKm.toStringAsFixed(0)} km) — limite de ~${_maxDiagonalKm.toStringAsFixed(0)} km (aprox. 1-2 estados). Selecione uma área menor.');
      return;
    }

    setState(() {
      _areaSelecionada = SelectedArea(
        south: south,
        north: north,
        west: west,
        east: east,
        diagonalKm: diagonalKm,
      );
      _ultimaAreaSalva = _areaSelecionada; // salva permanentemente⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️
      // TODO: é aqui que entra a chamada ao backend/OpenTopography,
      // usando _areaSelecionada!.south/north/west/east
      // Ex: backendService.buscarRelevo(_areaSelecionada!);
    });
  }

  /// Some com a área ativa (badge + polígono no mapa) mas MANTÉM o que
  /// já foi salvo em [_ultimaAreaSalva] — chamado ao clicar fora do
  /// mapa ou ao desligar o switch de seleção.
  void _limparSelecaoAtiva() {
    if (_areaSelecionada == null) return;
    setState(() => _areaSelecionada = null);
  }

  /// Traz de volta a última área salva como área ativa — chamado ao
  /// tocar no card "Última Área Selecionada".
  void _restaurarUltimaArea() {
    if (_ultimaAreaSalva == null) return;
    setState(() => _areaSelecionada = _ultimaAreaSalva);
  }

  Future<void> _copiarCoordenadas(SelectedArea area) async {
    final texto =
        'south: ${area.south}, north: ${area.north}, west: ${area.west}, east: ${area.east}';
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coordenadas copiadas!'), duration: Duration(seconds: 2)),
    );
  }

  void _avisarArea(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), duration: const Duration(seconds: 3)),
    );
  }

  /// Camada de gesto (transparente) que captura o arraste só quando
  /// [_selecionandoArea] está ligado. Fica FORA do FlutterMap (é espaço
  /// de tela, não camada georreferenciada) — por isso entra como irmão
  /// dele no Stack.
  Widget _buildAreaSelectionGestureOverlay() {
    Rect? liveRect;
    if (_dragStartOffset != null && _dragCurrentOffset != null) {
      liveRect = Rect.fromPoints(_dragStartOffset!, _dragCurrentOffset!);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_selecionandoArea,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: _onAreaPanStart,
              onPanUpdate: _onAreaPanUpdate,
              onPanEnd: _onAreaPanEnd,
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
      ],
    );
  }

  /// Row compacta com o switch "Selecionar área" — usada na legenda
  /// (web) e acima do mapa (mobile).
  Widget _buildSelectAreaSwitch() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.crop_free, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        const Text('Selecionar área',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Switch(
          value: _selecionandoArea,
          onChanged: (v) {
            setState(() {
              _selecionandoArea = v;
              if (!v) _areaSelecionada = null; // some ao desligar
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Stack(
        children: [
          // Camada de fundo: qualquer toque em espaço "vazio" (fora de
          // botões, switches, cards, mapa) cai aqui e limpa a seleção
          // ativa. Fica ATRÁS do conteúdo normal no Stack, então
          // qualquer widget interativo por cima consome o toque antes.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _limparSelecaoAtiva,
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWeb = constraints.maxWidth >= _webBreakpoint;
              return isWeb ? _buildWebBody(context) : _buildMobileBody(context);
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // WEB LAYOUT
  // ---------------------------------------------------------------------

  Widget _buildWebBody(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LOGISTICS INFRASTRUCTURE / TELEMETRY NODES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      'Map View',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const _ProjectChip(),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _buildLegendRow(),
                const SizedBox(height: AppSpacing.sm),
                _buildWebMapContainer(),
                const SizedBox(height: AppSpacing.lg),
                _buildMetricsGrid(context),
              ],
            ),
          ),
        ),
        // Preenche o espaço que sobrar da viewport com o rodapé
        // encostado embaixo — se o conteúdo já for mais alto que a
        // tela, isso não faz nada além de deixar o rodapé no final
        // do scroll (não fixo).
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [AppFooter()],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendRow() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const _LegendDot(color: AppColors.primary, label: 'Gateway (GW-01)'),
        const _LegendDot(color: Color(0xFF20232E), label: 'Sensor Node'),
        const _LegendRing(label: 'Coverage Mesh'),
        _buildSelectAreaSwitch(),
      ],
    );
  }

  Widget _buildWebMapContainer() {
    return Container(
      height: 720,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _gatewayPosition,
              initialZoom: 15.5,
              // minZoom reduzido — antes travava em 10 (só dava pra ver
              // no nível de quarteirão), o que impedia selecionar uma
              // área grande.
              minZoom: 3,
              maxZoom: 18,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all, // habilita zoom com scroll do mouse
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.tecsys.app',
              ),

              // Camada de relevo NASA GIBS, condicional ao toggle.
              // maxNativeZoom: 12 — esse layer só tem imagem nativa até
              // o zoom 12; sem isso, em zooms mais próximos (o mapa abre
              // em 15.5) ele pede um tile que não existe e não aparece
              // nada. Com maxNativeZoom, o flutter_map reaproveita o
              // tile do zoom 12 e amplia.
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

              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _gatewayPosition,
                    radius: 250,
                    useRadiusInMeter: true,
                    color: AppColors.coverageFill,
                    borderColor: AppColors.coverageBorder,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),

              // Retângulo de área confirmado (georreferenciado, acompanha
              // pan/zoom corretamente)
              if (_areaSelecionada != null)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _areaSelecionada!.corners,
                      color: AppColors.coverageFill,
                      borderColor: AppColors.coverageBorder,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),

              PolylineLayer(
                polylines: [
                  for (final s in _sensorPositions)
                    ..._dashedLine(_gatewayPosition, s),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _gatewayPosition,
                    width: 160,
                    height: 80,
                    alignment: Alignment.bottomCenter,
                    child: const _PinMarker(
                      label: 'Gateway GW-01',
                      icon: Icons.cell_tower,
                      pinColor: AppColors.primary,
                    ),
                  ),
                  for (var i = 0; i < _sensorPositions.length; i++)
                    Marker(
                      point: _sensorPositions[i],
                      width: 140,
                      height: 70,
                      alignment: Alignment.bottomCenter,
                      child: _PinMarker(
                        label: 'Sensor ${_sensorLabels[i]}',
                        icon: Icons.sensors,
                        pinColor: const Color(0xFF20232E),
                        small: true,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Camada de gesto de seleção de área (por cima do mapa; só
          // intercepta o arraste quando o switch acima está ligado)
          Positioned.fill(child: _buildAreaSelectionGestureOverlay()),

          // Badge de coordenada — agora mostra a área REAL selecionada,
          // atualiza sempre que uma nova área é confirmada.
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            child: _LocationBadge(area: _areaSelecionada, onCopy: _copiarCoordenadas),
          ),

          // Zoom / map controls (top-right)
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Column(
              children: [
                _MapControlButton(
                  icon: Icons.add,
                  onTap: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1),
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.remove,
                  onTap: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1),
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.gps_fixed,
                  onTap: () => _mapController.move(_gatewayPosition, 15.5),
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.layers_outlined,
                  onTap: () =>
                      setState(() => _mostrarPainelCamadas = !_mostrarPainelCamadas),
                ),
              ],
            ),
          ),

          // Floating gateway status card (bottom-left)
          Positioned(
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: _GatewayStatusCard(onTap: () {}),
          ),
          // Scale bar (bottom-right)
          const Positioned(
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: _ScaleBadge(),
          ),

          // Barreira invisível + painel de camadas — fecham ao tocar
          // fora. Ficam por último no Stack pra renderizar por cima
          // de tudo enquanto abertos.
          if (_mostrarPainelCamadas) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _mostrarPainelCamadas = false),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: AppSpacing.sm,
              right: 60,
              child: _MapLayersPanel(
                mostrarRelevo: _mostrarRelevoNasa,
                onMostrarRelevoChanged: (v) =>
                    setState(() => _mostrarRelevoNasa = v),
                opacidadeRelevo: _opacidadeRelevo,
                onOpacidadeChanged: (v) => setState(() => _opacidadeRelevo = v),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Grade de métricas — mesma pros dois layouts (4 colunas larga, 2
  // colunas estreita), pra web e mobile mostrarem os mesmos cards.
  static const _metrics = [
    (icon: Icons.dns_outlined, label: 'Operational Gateways', value: '1/1', caption: '100% Online', captionColor: AppColors.success),
    (icon: Icons.podcasts, label: 'Active Linked Sensors', value: '14 Nodes', caption: '2 Standby', captionColor: AppColors.textSecondary),
    (icon: Icons.speed_outlined, label: 'Mesh Health Latency', value: '32 ms', caption: 'Optimal', captionColor: AppColors.success),
  ];

  Widget _buildMetricsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 2;
        const spacing = AppSpacing.sm;
        final cardWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final cards = <Widget>[
          ..._metrics.map((m) => _WebMetricCard(
                icon: m.icon,
                label: m.label,
                value: m.value,
                caption: m.caption,
                captionColor: m.captionColor,
              )),
          _SavedAreaCard(
            area: _ultimaAreaSalva,
            onTap: _restaurarUltimaArea,
            onCopy: _copiarCoordenadas,
          ),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // MOBILE LAYOUT
  // ---------------------------------------------------------------------

  Widget _buildMobileBody(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // 1. Header
        Row(
          children: [
            Image.asset('assets/images/logo.png', height: 26),
            const Spacer(),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'TECSYS B2B',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3),
                ),
                SizedBox(height: 2),
                Text(
                  'Map',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(width: 12),
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // 2. Active project card
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.infoBlueBg,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.hub_outlined,
                    size: 20, color: AppColors.infoBlue),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Project Alpha',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                          ),
                        ),
                        Text('  •  São Paulo',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        const Text('CONNECTED',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // 2.5 Switch de seleção de área (mobile não tem legenda, então
        // fica aqui, acima do mapa)
        Align(alignment: Alignment.centerRight, child: _buildSelectAreaSwitch()),
        const SizedBox(height: AppSpacing.sm),
        // 3. Map container
        Container(
          height: 620,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _gatewayPosition,
                  initialZoom: 15.5,
                  minZoom: 3,
                  maxZoom: 18,
                  interactionOptions:
                      InteractionOptions(flags: InteractiveFlag.all),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.tecsys.app',
                  ),

                  // Camada de relevo NASA GIBS
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

                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _gatewayPosition,
                        radius: 250,
                        useRadiusInMeter: true,
                        color: AppColors.coverageFill,
                        borderColor: AppColors.coverageBorder,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),

                  // Retângulo de área confirmado
                  if (_areaSelecionada != null)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: _areaSelecionada!.corners,
                          color: AppColors.coverageFill,
                          borderColor: AppColors.coverageBorder,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),

                  PolylineLayer(
                      polylines:
                          _dashedLine(_gatewayPosition, _sensorPositions[0])),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _gatewayPosition,
                        width: 150,
                        height: 80,
                        alignment: Alignment.bottomCenter,
                        child: const _PinMarker(
                          label: 'Gateway (GW-01)',
                          icon: Icons.cell_tower,
                          pinColor: AppColors.primary,
                        ),
                      ),
                      Marker(
                        point: _sensorPositions[0],
                        width: 150,
                        height: 80,
                        alignment: Alignment.bottomCenter,
                        child: const _PinMarker(
                          label: 'Sensor (SN-102)',
                          icon: Icons.sensors,
                          pinColor: Color(0xFF20232E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Camada de gesto de seleção de área
              Positioned.fill(child: _buildAreaSelectionGestureOverlay()),

              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: _CompactCoordinateChip(
                  area: _areaSelecionada,
                  onCopy: _copiarCoordenadas,
                ),
              ),
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Column(
                  children: [
                    _MapControlButton(
                      icon: Icons.add,
                      onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1),
                    ),
                    const SizedBox(height: 8),
                    _MapControlButton(
                      icon: Icons.remove,
                      onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1),
                    ),
                    const SizedBox(height: 8),
                    _MapControlButton(
                      icon: Icons.crop_free,
                      onTap: () =>
                          _mapController.move(_gatewayPosition, 15.5),
                    ),
                    const SizedBox(height: 8),
                    _MapControlButton(
                      icon: Icons.layers_outlined,
                      onTap: () => setState(
                          () => _mostrarPainelCamadas = !_mostrarPainelCamadas),
                    ),
                  ],
                ),
              ),

              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: _GatewayStatusCard(onTap: () {}),
              ),

              // Barreira + painel — fecham ao tocar fora
              if (_mostrarPainelCamadas) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _mostrarPainelCamadas = false),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Positioned(
                  top: 56,
                  right: AppSpacing.sm,
                  child: _MapLayersPanel(
                    mostrarRelevo: _mostrarRelevoNasa,
                    onMostrarRelevoChanged: (v) =>
                        setState(() => _mostrarRelevoNasa = v),
                    opacidadeRelevo: _opacidadeRelevo,
                    onOpacidadeChanged: (v) =>
                        setState(() => _opacidadeRelevo = v),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // 4. Mesmos cards de métrica do web — mesmo conteúdo, mesmo widget.
              _buildMetricsGrid(context),
            ]),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [AppFooter()],
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// PAINEL DE CAMADAS (só relevo GIBS)
// ===========================================================================

class _MapLayersPanel extends StatelessWidget {
  const _MapLayersPanel({
    required this.mostrarRelevo,
    required this.onMostrarRelevoChanged,
    required this.opacidadeRelevo,
    required this.onOpacidadeChanged,
  });

  final bool mostrarRelevo;
  final ValueChanged<bool> onMostrarRelevoChanged;
  final double opacidadeRelevo;
  final ValueChanged<double> onOpacidadeChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.terrain, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                const Text('Relevo NASA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Switch(value: mostrarRelevo, onChanged: onMostrarRelevoChanged),
              ],
            ),
            if (mostrarRelevo) ...[
              const SizedBox(height: 4),
              Text(
                'Opacidade: ${(opacidadeRelevo * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              SizedBox(
                width: 170,
                child: Slider(
                  value: opacidadeRelevo,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  onChanged: onOpacidadeChanged,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// WEB-ONLY WIDGETS
// ===========================================================================

class _ProjectChip extends StatelessWidget {
  const _ProjectChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.circle, size: 8, color: AppColors.success),
          SizedBox(width: 6),
          Text('Project Alpha — São Paulo',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _LegendRing extends StatelessWidget {
  final String label;
  const _LegendRing({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.coverageBorder, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _LocationBadge extends StatelessWidget {
  final SelectedArea? area;
  final ValueChanged<SelectedArea>? onCopy;
  const _LocationBadge({required this.area, this.onCopy});

  @override
  Widget build(BuildContext context) {
    final title = area == null
        ? 'Nenhuma área selecionada'
        : 'Área selecionada (~${area!.diagonalKm.toStringAsFixed(0)} km)';
    final subtitle = area == null
        ? 'Ligue "Selecionar área" e arraste no mapa'
        : 'SW ${area!.south.toStringAsFixed(4)}, ${area!.west.toStringAsFixed(4)}  •  '
            'NE ${area!.north.toStringAsFixed(4)}, ${area!.east.toStringAsFixed(4)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(subtitle,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
          if (area != null && onCopy != null) ...[
            const SizedBox(width: 4),
            _CopyIconButton(onCopy: () => onCopy!(area!), size: 14),
          ],
        ],
      ),
    );
  }
}

/// Botão de copiar reutilizável — mostra um ✓ por 2s depois de copiar,
/// antes de voltar ao ícone normal.
class _CopyIconButton extends StatefulWidget {
  final VoidCallback onCopy;
  final double size;
  final Color color;

  const _CopyIconButton({
    required this.onCopy,
    this.size = 14,
    this.color = AppColors.textSecondary,
  });

  @override
  State<_CopyIconButton> createState() => _CopyIconButtonState();
}

class _CopyIconButtonState extends State<_CopyIconButton> {
  bool _copiado = false;

  void _handleTap() {
    widget.onCopy();
    setState(() => _copiado = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiado = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(100),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          _copiado ? Icons.check : Icons.copy,
          size: widget.size,
          color: _copiado ? AppColors.success : widget.color,
        ),
      ),
    );
  }
}

class _GatewayStatusCard extends StatelessWidget {
  final VoidCallback onTap;
  const _GatewayStatusCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Gateway GW-01',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.infoBlueBg, borderRadius: BorderRadius.circular(100)),
                child: const Text('ACTIVE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.infoBlue)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              _MiniStat(label: 'Signal', value: '98%'),
              SizedBox(width: 16),
              _MiniStat(label: 'Coverage', value: '2.5 km'),
              SizedBox(width: 16),
              _MiniStat(label: 'Nodes', value: '14/16'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Last packet: 4s ago',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const Spacer(),
              InkWell(
                onTap: onTap,
                child: const Text('Node Details →',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }
}

class _ScaleBadge extends StatelessWidget {
  const _ScaleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('Scale: 1:25,000    500 m',
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    );
  }
}

class _WebMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color captionColor;

  const _WebMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.captionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.infoBlueBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.infoBlue),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                Text(caption, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: captionColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedAreaCard extends StatelessWidget {
  final SelectedArea? area;
  final VoidCallback onTap;
  final ValueChanged<SelectedArea> onCopy;

  const _SavedAreaCard({required this.area, required this.onTap, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final semArea = area == null;
    return InkWell(
      onTap: semArea ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E8EF)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: AppColors.infoBlueBg, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.bookmark_outline, size: 18, color: AppColors.infoBlue),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Última Área Selecionada',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(
                    semArea
                        ? '—'
                        : 'SW ${area!.south.toStringAsFixed(3)}, ${area!.west.toStringAsFixed(3)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    semArea
                        ? 'Nenhuma área salva ainda'
                        : 'NE ${area!.north.toStringAsFixed(3)}, ${area!.east.toStringAsFixed(3)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!semArea)
              _CopyIconButton(
                onCopy: () => onCopy(area!),
                size: 16,
                color: AppColors.infoBlue,
              ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// SHARED WIDGETS (mobile + web)
// ===========================================================================

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(color: AppColors.infoBlueBg, shape: BoxShape.circle),
        child: Icon(icon, size: 17, color: AppColors.infoBlue),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}

class _FloatingChip extends StatelessWidget {
  final Widget child;
  const _FloatingChip({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.9),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)],
      ),
      child: child,
    );
  }
}

/// Chip mínimo pro mobile — só a coordenada (canto SW da área) e o
/// botão de copiar. Some (não ocupa espaço) quando não há seleção,
/// pra não poluir a tela.
class _CompactCoordinateChip extends StatelessWidget {
  final SelectedArea? area;
  final ValueChanged<SelectedArea> onCopy;

  const _CompactCoordinateChip({required this.area, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    if (area == null) return const SizedBox.shrink();

    return _FloatingChip(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${area!.south.toStringAsFixed(4)}, ${area!.west.toStringAsFixed(4)}',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 4),
          _CopyIconButton(onCopy: () => onCopy(area!), size: 13),
        ],
      ),
    );
  }
}

/// Pin-shaped marker with a label bubble above it — used for the
/// gateway and every sensor.
class _PinMarker extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color pinColor;
  final bool small;

  const _PinMarker({
    required this.label,
    required this.icon,
    required this.pinColor,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final pinSize = small ? 26.0 : 34.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.95),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 5, height: 5, decoration: BoxDecoration(color: pinColor, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: pinSize,
          height: pinSize,
          decoration: BoxDecoration(
            color: pinColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4)],
          ),
          child: Icon(icon, size: small ? 13 : 16, color: Colors.white),
        ),
      ],
    );
  }
}