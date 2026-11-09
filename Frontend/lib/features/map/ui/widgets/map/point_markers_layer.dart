import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:tecsys_app/features/map/data/models/map_point.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

/// Elementos individuais (zoom de perto), cada categoria com um formato:
/// * ponto a cobrir (consumidor): círculo na cor da tensão;
/// * local para gateway (transformador): losango com borda escura;
/// * rede (trechos e subestação): pontinho pequeno e apagado, só desenho.
/// A cor continua indicando a tensão; o formato diz o papel no cálculo.
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

  /// Tamanho do pontinho da rede em relação ao marcador normal.
  static const fatorRede = 0.45;
  static const opacidadeRede = 0.55;

  /// O losango é um quadrado girado: um pouco maior para ter a mesma área.
  static const fatorCandidato = 0.8;
  static const bordaCandidato = Color(0xFF263238);

  Color _cor(MapPoint ponto, {double opacidade = 1}) {
    final cor = MapStyles.layerColor(ponto.layer);
    final dentro = destacado?.call(ponto.position) ?? true;
    final alfa = dentro ? opacidade : MapStyles.markerOutsideAreaOpacity;
    return cor.withOpacity(cor.opacity * alfa);
  }

  static int _ordem(MapPoint p) => switch (p.categoria) {
        CategoriaPonto.rede => 0,
        CategoriaPonto.candidato => 1,
        CategoriaPonto.ponto => 2,
      };

  Marker _marcador(MapPoint ponto) {
    const tam = MapStyles.markerSize;
    final Widget forma = switch (ponto.categoria) {
      CategoriaPonto.ponto => DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: _cor(ponto)),
        ),
      CategoriaPonto.candidato => Center(
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: tam * fatorCandidato,
              height: tam * fatorCandidato,
              decoration: BoxDecoration(
                color: _cor(ponto),
                border: Border.all(color: bordaCandidato, width: 1.5),
              ),
            ),
          ),
        ),
      CategoriaPonto.rede => Center(
          child: Container(
            width: tam * fatorRede,
            height: tam * fatorRede,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _cor(ponto, opacidade: opacidadeRede),
            ),
          ),
        ),
    };
    return Marker(
      point: ponto.position,
      width: tam,
      height: tam,
      child: GestureDetector(onTap: () => onTap(ponto), child: forma),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rede embaixo, consumidores por cima.
    final ordenados = [
      for (final p in pontos)
        if (!p.isCluster) p,
    ]..sort((a, b) => _ordem(a).compareTo(_ordem(b)));
    return MarkerLayer(markers: [for (final p in ordenados) _marcador(p)]);
  }
}
