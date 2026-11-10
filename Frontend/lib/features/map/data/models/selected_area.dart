import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

@immutable
class SelectedArea {
  final double north;
  final double south;
  final double west;
  final double east;

  const SelectedArea({
    required this.north,
    required this.south,
    required this.west,
    required this.east,
  });

  factory SelectedArea.fromCorners(LatLng a, LatLng b) => SelectedArea(
        north: math.max(a.latitude, b.latitude),
        south: math.min(a.latitude, b.latitude),
        west: math.min(a.longitude, b.longitude),
        east: math.max(a.longitude, b.longitude),
      );

  LatLng get northWest => LatLng(north, west);
  LatLng get southEast => LatLng(south, east);

  List<LatLng> get corners => [
        LatLng(north, west),
        LatLng(north, east),
        LatLng(south, east),
        LatLng(south, west),
      ];

  bool contains(LatLng p) =>
      p.latitude <= north &&
      p.latitude >= south &&
      p.longitude >= west &&
      p.longitude <= east;

  double get widthKm =>
      const Distance().as(LengthUnit.Meter, LatLng(north, west), LatLng(north, east)) / 1000;

  double get heightKm =>
      const Distance().as(LengthUnit.Meter, LatLng(north, west), LatLng(south, west)) / 1000;

  List<List<double>> toRing() {
    double arred(double v) => double.parse(v.toStringAsFixed(6));
    return [
      [arred(west), arred(north)],
      [arred(east), arred(north)],
      [arred(east), arred(south)],
      [arred(west), arred(south)],
      [arred(west), arred(north)],
    ];
  }

  static Map<String, dynamic>? toGeoJson(List<SelectedArea> areas) {
    if (areas.isEmpty) return null;
    if (areas.length == 1) {
      return {
        'type': 'Polygon',
        'coordinates': [areas.first.toRing()],
      };
    }
    return {
      'type': 'MultiPolygon',
      'coordinates': [
        for (final a in areas) [a.toRing()],
      ],
    };
  }

  /// Áreas de um GeoJSON salvo (Polygon ou MultiPolygon), como as que
  /// [toGeoJson] gera. Cada anel vira o retângulo que o contém.
  static List<SelectedArea> fromGeoJson(Map<String, dynamic>? geo) {
    if (geo == null) return const [];
    final coords = geo['coordinates'];
    if (coords is! List) return const [];
    final List<dynamic> poligonos = switch (geo['type']) {
      'Polygon' => [coords],
      'MultiPolygon' => coords,
      _ => const [],
    };
    final areas = <SelectedArea>[];
    for (final poligono in poligonos) {
      if (poligono is! List || poligono.isEmpty || poligono.first is! List) {
        continue;
      }
      final pontos = <LatLng>[
        for (final c in poligono.first as List)
          if (c is List && c.length >= 2 && c[0] is num && c[1] is num)
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];
      if (pontos.length < 3) continue;
      final lats = pontos.map((p) => p.latitude);
      final lons = pontos.map((p) => p.longitude);
      areas.add(SelectedArea(
        north: lats.reduce(math.max),
        south: lats.reduce(math.min),
        west: lons.reduce(math.min),
        east: lons.reduce(math.max),
      ));
    }
    return areas;
  }

  @override
  bool operator ==(Object other) =>
      other is SelectedArea &&
      other.north == north &&
      other.south == south &&
      other.west == west &&
      other.east == east;

  @override
  int get hashCode => Object.hash(north, south, west, east);
}