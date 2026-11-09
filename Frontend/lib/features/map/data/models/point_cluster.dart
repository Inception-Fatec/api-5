import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'package:tecsys_app/features/map/data/models/map_point.dart';

class PointCluster {
  final LatLng position;
  final int count;

  const PointCluster({required this.position, required this.count});
}

class Agrupamento {
  final double zoom;
  final double pixels;
  final List<PointCluster> bolhas;
  final Map<int, PointCluster> _porQuadrado;

  Agrupamento._(this.zoom, this.pixels, this._porQuadrado)
      : bolhas = List.unmodifiable(_porQuadrado.values);

  factory Agrupamento.vazio() => Agrupamento._(0, 1, {});

  factory Agrupamento.de(List<MapPoint> celulas, double zoom, double pixels) {
    final somas = <int, _Soma>{};
    for (final c in celulas) {
      (somas[_quadrado(c.position, zoom, pixels)] ??= _Soma())
          .somar(c.position, c.clusterCount);
    }
    return Agrupamento._(
      zoom,
      pixels,
      {for (final e in somas.entries) e.key: e.value.bolha()},
    );
  }

  PointCluster? bolhaEm(LatLng p) => _porQuadrado[_quadrado(p, zoom, pixels)];

  static int _quadrado(LatLng p, double zoom, double pixels) {
    final escala = 256 * math.pow(2, zoom).toDouble();
    final lat = p.latitude.clamp(-85.0, 85.0);
    final x = (p.longitude + 180) / 360 * escala;
    final s = math.sin(lat * math.pi / 180);
    final y = (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * escala;
    return (x ~/ pixels) * 1000003 + (y ~/ pixels);
  }
}

class _Soma {
  double lat = 0, lon = 0;
  int n = 0;

  void somar(LatLng p, int qtd) {
    lat += p.latitude * qtd;
    lon += p.longitude * qtd;
    n += qtd;
  }

  PointCluster bolha() =>
      PointCluster(position: LatLng(lat / n, lon / n), count: n);
}
