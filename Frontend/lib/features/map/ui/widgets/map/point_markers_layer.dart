import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:tecsys_app/features/map/data/models/map_point.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

class PointMarkersLayer extends StatelessWidget {
  final List<MapPoint> pontos;
  final ValueChanged<MapPoint> onTap;
  final bool Function(LatLng posicao)? destacado;

  const PointMarkersLayer({
    super.key,
    required this.pontos,
    required this.onTap,
    this.destacado,
  });

  Color _cor(MapPoint ponto) {
    final cor = MapStyles.layerColor(ponto.layer);
    final dentro = destacado?.call(ponto.position) ?? true;
    return dentro ? cor : cor.withOpacity(MapStyles.markerOutsideAreaOpacity);
  }

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        for (final ponto in pontos)
          Marker(
            point: ponto.position,
            width: MapStyles.markerSize,
            height: MapStyles.markerSize,
            child: GestureDetector(
              onTap: () => onTap(ponto),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _cor(ponto),
                ),
              ),
            ),
          ),
      ],
    );
  }
}