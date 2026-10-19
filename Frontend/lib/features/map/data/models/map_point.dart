import 'package:latlong2/latlong.dart';

/// Um ponto devolvido pelo backend (feature GeoJSON) já com a posição
/// que o mapa usa para desenhá-lo.
class MapPoint {
  final Map<String, dynamic> feature;
  final LatLng position;

  const MapPoint({required this.feature, required this.position});

  /// Monta o ponto a partir de uma feature GeoJSON; null se a geometria
  /// não tiver coordenadas utilizáveis.
  static MapPoint? fromFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? const {};
    final position = representativePoint(geometry);
    return position == null
        ? null
        : MapPoint(feature: feature, position: position);
  }

  Map<String, dynamic> get properties =>
      (feature['properties'] as Map<String, dynamic>?) ?? const {};

  String? get id => properties['id']?.toString();

  /// Camada do ponto (ALTO, MEDIO, BAIXO, SUB...).
  String? get layer => properties['layer'] as String?;

  /// Ponto único que representa uma geometria GeoJSON: o próprio ponto,
  /// ou a média dos vértices (do primeiro anel/linha, nas demais).
  static LatLng? representativePoint(Map<String, dynamic> geom) {
    final tipo = geom['type'];
    if (tipo == 'Point') {
      final c = geom['coordinates'] as List?;
      if (c == null || c.length < 2) return null;
      return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
    }

    List? vertices;
    if (tipo == 'Polygon') {
      final aneis = geom['coordinates'] as List?;
      vertices =
          (aneis != null && aneis.isNotEmpty) ? aneis.first as List? : null;
    } else if (tipo == 'MultiPolygon') {
      final polis = geom['coordinates'] as List?;
      final primeiro =
          (polis != null && polis.isNotEmpty) ? polis.first as List? : null;
      vertices = (primeiro != null && primeiro.isNotEmpty)
          ? primeiro.first as List?
          : null;
    } else if (tipo == 'LineString') {
      vertices = geom['coordinates'] as List?;
    } else if (tipo == 'MultiLineString') {
      final linhas = geom['coordinates'] as List?;
      vertices =
          (linhas != null && linhas.isNotEmpty) ? linhas.first as List? : null;
    }
    if (vertices == null || vertices.isEmpty) return null;

    var somaLat = 0.0, somaLon = 0.0;
    for (final v in vertices) {
      final p = v as List;
      somaLon += (p[0] as num).toDouble();
      somaLat += (p[1] as num).toDouble();
    }
    final n = vertices.length;
    return LatLng(somaLat / n, somaLon / n);
  }
}
