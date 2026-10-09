import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:latlong2/latlong.dart';

class MapViewport {
  final double zoom;
  final double west;
  final double south;
  final double east;
  final double north;

  const MapViewport({
    required this.zoom,
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });
  Map<String, dynamic> toPolygonGeoJson() {
    return {
      'type': 'Polygon',
      'coordinates': [
        [
          [west, south],
          [east, south],
          [east, north],
          [west, north],
          [west, south],
        ]
      ],
    };
  }
  LatLng screenToLatLng(Offset ponto, Size size) {
    final lon = west + (east - west) * (ponto.dx / size.width);

    double mercY(double lat) {
      final r = lat * math.pi / 180;
      return math.log(math.tan(math.pi / 4 + r / 2));
    }

    final yNorte = mercY(north);
    final ySul = mercY(south);
    final y = yNorte + (ySul - yNorte) * (ponto.dy / size.height);
    final lat = (2 * math.atan(math.exp(y)) - math.pi / 2) * 180 / math.pi;

    return LatLng(lat, lon);
  }
}