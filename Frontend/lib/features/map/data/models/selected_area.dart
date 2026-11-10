import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Área desenhada no mapa: um polígono simples, guardado pelos vértices na
/// ordem em que foram clicados (sem repetir o primeiro no fim). Um retângulo
/// é só um polígono de 4 vértices (#TG-146).
@immutable
class SelectedArea {
  /// Vértices do polígono (pelo menos 3), sem fechar o anel.
  final List<LatLng> vertices;

  SelectedArea(List<LatLng> vertices)
      : assert(vertices.length >= 3, 'um polígono precisa de 3 vértices'),
        vertices = List.unmodifiable(vertices);

  /// Retângulo alinhado ao norte (o desenho antigo, e o atalho "Retângulo").
  factory SelectedArea.retangulo({
    required double north,
    required double south,
    required double west,
    required double east,
  }) =>
      SelectedArea([
        LatLng(north, west),
        LatLng(north, east),
        LatLng(south, east),
        LatLng(south, west),
      ]);

  factory SelectedArea.fromCorners(LatLng a, LatLng b) =>
      SelectedArea.retangulo(
        north: math.max(a.latitude, b.latitude),
        south: math.min(a.latitude, b.latitude),
        west: math.min(a.longitude, b.longitude),
        east: math.max(a.longitude, b.longitude),
      );

  /// Mínimo de vértices de um polígono.
  static const int minVertices = 3;

  // Retângulo que envolve o polígono (enquadrar a câmera, centro inicial).
  double get north => vertices.map((p) => p.latitude).reduce(math.max);
  double get south => vertices.map((p) => p.latitude).reduce(math.min);
  double get west => vertices.map((p) => p.longitude).reduce(math.min);
  double get east => vertices.map((p) => p.longitude).reduce(math.max);

  LatLng get northWest => LatLng(north, west);
  LatLng get southEast => LatLng(south, east);

  /// Pontos para desenhar o polígono no mapa.
  List<LatLng> get corners => vertices;

  /// Ponto dentro do polígono (ray casting). Pontos exatamente na borda podem
  /// cair de qualquer lado; o PostGIS (ST_Intersects) decide o que conta.
  bool contains(LatLng p) => pontoNoPoligono(p, vertices);

  static bool pontoNoPoligono(LatLng p, List<LatLng> poligono) {
    final x = p.longitude, y = p.latitude;
    var dentro = false;
    for (var i = 0, j = poligono.length - 1; i < poligono.length; j = i++) {
      final xi = poligono[i].longitude, yi = poligono[i].latitude;
      final xj = poligono[j].longitude, yj = poligono[j].latitude;
      if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
        dentro = !dentro;
      }
    }
    return dentro;
  }

  /// Área em km² (projeção equiretangular local + fórmula do laço). O erro é
  /// desprezível para áreas do tamanho de cidades.
  double get areaKm2 {
    const raioKm = 6371.0088;
    final lat0 = (north + south) / 2 * math.pi / 180;
    final pts = [
      for (final v in vertices)
        (
          v.longitude * math.pi / 180 * raioKm * math.cos(lat0),
          v.latitude * math.pi / 180 * raioKm,
        ),
    ];
    var soma = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i], b = pts[(i + 1) % pts.length];
      soma += a.$1 * b.$2 - b.$1 * a.$2;
    }
    return soma.abs() / 2;
  }

  /// Algum lado cruza outro lado não vizinho ("gravata borboleta")? O
  /// PostGIS trataria esse polígono como geometria inválida.
  bool get seCruza => cruzaASiMesmo(vertices);

  static bool cruzaASiMesmo(List<LatLng> poligono) {
    final n = poligono.length;
    if (n < 4) return false;
    for (var i = 0; i < n; i++) {
      final a1 = poligono[i], a2 = poligono[(i + 1) % n];
      for (var j = i + 1; j < n; j++) {
        // Lados vizinhos compartilham um vértice: não contam.
        if (j == i + 1 || (i == 0 && j == n - 1)) continue;
        final b1 = poligono[j], b2 = poligono[(j + 1) % n];
        if (_segmentosSeCruzam(a1, a2, b1, b2)) return true;
      }
    }
    return false;
  }

  /// O novo lado (último vértice -> [novo]) cruzaria algum lado já desenhado?
  /// Usado durante o desenho para recusar o clique na hora.
  static bool novoLadoCruza(List<LatLng> abertos, LatLng novo) {
    if (abertos.length < 3) return false;
    final a1 = abertos.last;
    for (var i = 0; i < abertos.length - 2; i++) {
      if (_segmentosSeCruzam(a1, novo, abertos[i], abertos[i + 1])) return true;
    }
    return false;
  }

  static double _orientacao(LatLng p, LatLng q, LatLng r) =>
      (q.longitude - p.longitude) * (r.latitude - p.latitude) -
      (q.latitude - p.latitude) * (r.longitude - p.longitude);

  static bool _segmentosSeCruzam(LatLng p1, LatLng p2, LatLng q1, LatLng q2) {
    final d1 = _orientacao(q1, q2, p1);
    final d2 = _orientacao(q1, q2, p2);
    final d3 = _orientacao(p1, p2, q1);
    final d4 = _orientacao(p1, p2, q2);
    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
  }

  /// Anel GeoJSON [lon, lat], fechado com o primeiro vértice, 6 casas.
  List<List<double>> toRing() {
    double arred(double v) => double.parse(v.toStringAsFixed(6));
    return [
      for (final v in [...vertices, vertices.first])
        [arred(v.longitude), arred(v.latitude)],
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
  /// [toGeoJson] gera. Usa o anel externo de cada polígono, com os vértices
  /// como estão (projetos antigos com retângulo voltam iguais).
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
      // Anel fechado: o último repete o primeiro.
      if (pontos.length > 1 && pontos.first == pontos.last) pontos.removeLast();
      if (pontos.length < minVertices) continue;
      areas.add(SelectedArea(pontos));
    }
    return areas;
  }

  @override
  bool operator ==(Object other) =>
      other is SelectedArea && listEquals(other.vertices, vertices);

  @override
  int get hashCode => Object.hashAll(vertices);
}
