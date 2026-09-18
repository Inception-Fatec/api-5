import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import 'new_project_screen.dart';
import 'projects_screen.dart';

/// Map screen — built to spec: header, active-project card, the
/// flutter_map container (frequency tag, zoom/center controls,
/// gateway + sensor markers with label bubbles, dashed connecting
/// line, translucent coverage circle, floating gateway status card),
/// the Topology Overview section, and the bottom nav with "Map"
/// active.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _gatewayPosition = LatLng(-23.5505, -46.6333);
  static const _sensorPosition = LatLng(-23.5498, -46.6320);

  final MapController _mapController = MapController();

  void _handleTabTap(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProjectsScreen()),
        );
        break;
      case 1:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NewProjectScreen()),
        );
        break;
      case 2:
        break; // already here
      default:
        showAccountMenu(context);
    }
  }

  /// Approximates a dashed line: several short Polyline segments with
  /// gaps between the gateway and the sensor (flutter_map's Polyline
  /// has no built-in dash pattern).
  List<Polyline> _dashedLine(LatLng a, LatLng b) {
    const segments = 10;
    final segs = <Polyline>[];
    for (var i = 0; i < segments; i += 2) {
      final t0 = i / segments;
      final t1 = (i + 1) / segments;
      segs.add(Polyline(
        points: [
          LatLng(
            a.latitude + (b.latitude - a.latitude) * t0,
            a.longitude + (b.longitude - a.longitude) * t0,
          ),
          LatLng(
            a.latitude + (b.latitude - a.latitude) * t1,
            a.longitude + (b.longitude - a.longitude) * t1,
          ),
        ],
        color: AppColors.primary,
        strokeWidth: 2,
      ));
    }
    return segs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: BottomNavBar(currentIndex: 2, onTap: _handleTabTap),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Map',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
                    decoration: BoxDecoration(color: AppColors.infoBlueBg, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.hub_outlined, size: 20, color: AppColors.infoBlue),
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
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            Text('  •  São Paulo', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            const Text('CONNECTED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
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
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
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
                      PolylineLayer(polylines: _dashedLine(_gatewayPosition, _sensorPosition)),
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
                            point: _sensorPosition,
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
                  // Frequency tag
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _FloatingChip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          const Text('915 MHz LoRaWAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  // Zoom / center controls
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Column(
                      children: [
                        _MapControlButton(
                          icon: Icons.add,
                          onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                        ),
                        const SizedBox(height: 8),
                        _MapControlButton(
                          icon: Icons.remove,
                          onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                        ),
                        const SizedBox(height: 8),
                        _MapControlButton(
                          icon: Icons.crop_free,
                          onTap: () => _mapController.move(_gatewayPosition, 15.5),
                        ),
                      ],
                    ),
                  ),
                  // Floating gateway status card
                  Positioned(
                    left: AppSpacing.sm,
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(color: AppColors.infoBlueBg, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.podcasts, size: 19, color: AppColors.infoBlue),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Gateway: Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.infoBlueBg, borderRadius: BorderRadius.circular(100)),
                                      child: const Text('Optimal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.infoBlue)),
                                    ),
                                  ],
                                ),
                                const Text('1 Sensor within coverage range (~72m)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(color: AppColors.infoBlueBg, borderRadius: BorderRadius.circular(100)),
                            child: const Icon(Icons.chevron_right, size: 18, color: AppColors.infoBlue),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // 4. Topology Overview
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.hub_outlined, size: 18, color: AppColors.textPrimary),
                    SizedBox(width: 6),
                    Text('Topology Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
                const Text('Telemetry: Real-time', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _InfoCard(
                    label: 'Radius Coverage',
                    icon: Icons.radar,
                    value: '250 m',
                    caption: 'Omnidirectional',
                    captionColor: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _InfoCard(
                    label: 'Signal (RSSI)',
                    icon: Icons.signal_cellular_alt,
                    value: '-78 dBm',
                    caption: 'Excellent link',
                    captionColor: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.pageBg, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: AppColors.infoBlueBg, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.device_thermostat, size: 17, color: AppColors.infoBlue),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SN-102 • Cold Chain Monitor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text('Payload battery 98% • Latency 22ms', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(100)),
                    child: const Text('Normal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

/// Pin-shaped marker with a label bubble above it — used for both the
/// gateway and the sensor.
class _PinMarker extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color pinColor;

  const _PinMarker({required this.label, required this.icon, required this.pinColor});

  @override
  Widget build(BuildContext context) {
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: pinColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4)],
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String caption;
  final Color captionColor;

  const _InfoCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.caption,
    required this.captionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.pageBg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Icon(icon, size: 17, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text(caption, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: captionColor)),
        ],
      ),
    );
  }
}