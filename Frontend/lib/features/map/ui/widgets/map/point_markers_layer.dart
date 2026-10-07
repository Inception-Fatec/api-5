import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:tecsys_app/features/map/data/models/map_point.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

/// Marcadores dos pontos no mapa, coloridos pela camada de cada um.
class PointMarkersLayer extends StatelessWidget {
  final List<MapPoint> pontos;
  final ValueChanged<MapPoint> onTap;

  const PointMarkersLayer({
    super.key,
    required this.pontos,
    required this.onTap,
  });

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
                  color: MapStyles.layerColor(ponto.layer),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
