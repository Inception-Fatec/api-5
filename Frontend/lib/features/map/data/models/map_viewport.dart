/// Área visível do mapa no momento da busca: zoom e limites geográficos.
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

  /// Retângulo visível como polígono GeoJSON (formato aceito pelo
  /// backend em `polygon_geojson`).
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
}
