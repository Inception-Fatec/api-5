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