import 'package:latlong2/latlong.dart';

/// Bounding box no formato que o OpenTopography (e agora também o
/// endpoint de filtro de pontos, como polígono) espera, junto com a
/// diagonal aproximada em km.
class SelectedArea {
  final double south;
  final double north;
  final double west;
  final double east;
  final double diagonalKm;

  /// Rótulo legível (ex: nome da cidade retornado pela busca) — usado
  /// no histórico e nos badges. Null quando a área veio de um desenho
  /// manual no mapa, sem busca por nome.
  final String? label;

  const SelectedArea({
    required this.south,
    required this.north,
    required this.west,
    required this.east,
    required this.diagonalKm,
    this.label,
  });

  /// Os 4 cantos, na ordem certa pra desenhar o [Polygon] no
  /// flutter_map (fecha o retângulo).
  List<LatLng> get corners => [
        LatLng(north, west),
        LatLng(north, east),
        LatLng(south, east),
        LatLng(south, west),
      ];

  /// Mesmo retângulo, como um `Polygon` GeoJSON em WGS84 — é o formato
  /// que o campo `polygon_geojson` da API de filtro de pontos espera.
  /// GeoJSON usa [longitude, latitude] (nessa ordem) e exige que o
  /// primeiro e o último ponto do anel sejam iguais (polígono fechado).
  Map<String, dynamic> toGeoJsonPolygon() {
    final ring = [
      [west, north],
      [east, north],
      [east, south],
      [west, south],
      [west, north], // fecha o anel
    ];
    return {
      'type': 'Polygon',
      'coordinates': [ring],
    };
  }
}