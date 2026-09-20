import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../widgets/common/app_footer.dart';
import '../widgets/common/page_body.dart';

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

  static const _gatewayPosition = LatLng(-23.5505, -46.6333);
  static const _sensorPositions = [
    LatLng(-23.5498, -46.6320), // SN-102
    LatLng(-23.5512, -46.6348), // SN-088
    LatLng(-23.5518, -46.6329), // SN-094
  ];
  static const _sensorLabels = ['SN-102', 'SN-088', 'SN-094'];

  final MapController _mapController = MapController();

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

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = constraints.maxWidth >= _webBreakpoint;
          return isWeb ? _buildWebBody(context) : _buildMobileBody(context);
        },
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
        const Spacer(),
        _ToggleChip(label: 'Vector', selected: true, onTap: () {}),
        const SizedBox(width: 8),
        _ToggleChip(label: 'Telemetry', selected: false, onTap: () {}),
      ],
    );
  }

  Widget _buildWebMapContainer() {
    return Container(
      height: 560,
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
              minZoom: 10,
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
          // Location badge (top-left)
          const Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            child: _LocationBadge(
              title: 'Distrito Industrial Leste, SP',
              subtitle: '-23.1585°, -46.6333°',
            ),
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
                _MapControlButton(icon: Icons.layers_outlined, onTap: () {}),
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
        ],
      ),
    );
  }

  // Grade de métricas — mesma pros dois layouts (4 colunas larga, 2
  // colunas estreita), pra web e mobile mostrarem os mesmos cards.
  static const _metrics = [
    (icon: Icons.dns_outlined, label: 'Operational Gateways', value: '1/1', caption: '100% Online', captionColor: AppColors.success),
    (icon: Icons.podcasts, label: 'Active Linked Sensors', value: '14 Nodes', caption: '2 Standby', captionColor: AppColors.textSecondary),
    (icon: Icons.map_outlined, label: 'Area Coverage Ratio', value: '19.6 km²', caption: 'Full Density', captionColor: AppColors.success),
    (icon: Icons.speed_outlined, label: 'Mesh Health Latency', value: '32 ms', caption: 'Optimal', captionColor: AppColors.success),
  ];

  Widget _buildMetricsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 2;
        const spacing = AppSpacing.sm;
        final cardWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _metrics
              .map((m) => SizedBox(
                    width: cardWidth,
                    child: _WebMetricCard(
                      icon: m.icon,
                      label: m.label,
                      value: m.value,
                      caption: m.caption,
                      captionColor: m.captionColor,
                    ),
                  ))
              .toList(),
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
                        Text(
                          'Project Alpha',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                        Text('  •  São Paulo',
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
              _CircleIconButton(icon: Icons.layers_outlined, onTap: () {}),
              const SizedBox(width: 8),
              _CircleIconButton(icon: Icons.gps_fixed, onTap: () {}),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
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
                  minZoom: 10,
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
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: _FloatingChip(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text('915 MHz LoRaWAN',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                    ],
                  ),
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
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: _GatewayStatusCard(onTap: () {}),
              ),
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

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.infoBlueBg : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: selected ? AppColors.infoBlueBg : const Color(0xFFE4E8EF)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.infoBlue : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LocationBadge extends StatelessWidget {
  final String title;
  final String subtitle;
  const _LocationBadge({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
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
        ],
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