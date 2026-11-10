import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:tecsys_app/features/map/data/models/map_point.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

/// Elementos individuais (zoom de perto), com cores sólidas (#TG-92):
/// * ponto a cobrir: círculo na cor da tensão (alta laranja, média
///   amarela, baixa verde);
/// * candidato a gateway: losango roxo;
/// * rede (trechos, subestação, trafo que não é candidato): quadrado azul,
///   só desenho.
/// Uma camada nos dois papéis aparece com os dois marcadores.
class PointMarkersLayer extends StatelessWidget {
  final List<MapPoint> pontos;
  final ValueChanged<MapPoint> onTap;

  /// Mantido por compatibilidade; os marcadores não ficam mais
  /// transparentes fora da área.
  final bool Function(LatLng posicao)? destacado;

  const PointMarkersLayer({
    super.key,
    required this.pontos,
    required this.onTap,
    this.destacado,
  });

  /// Tamanho do quadrado da rede em relação ao marcador normal.
  static const fatorRede = 0.65;

  /// O losango é um quadrado girado: um pouco maior para ter a mesma área.
  static const fatorCandidato = 0.85;
  static const bordaCandidato = MapStyles.bordaCandidato;

  /// Cor do marcador: candidato e rede pela cor do papel; ponto a cobrir
  /// pela tensão.
  static Color corDe(CategoriaPonto papel, String? layer) => switch (papel) {
        CategoriaPonto.ponto => MapStyles.corDaTensao(layer),
        CategoriaPonto.candidato => MapStyles.corCandidato,
        CategoriaPonto.rede => MapStyles.corRede,
      };

  Color _cor(MapPoint ponto) => corDe(ponto.categoria, ponto.layer);

  static int _ordem(MapPoint p) => switch (p.categoria) {
        CategoriaPonto.rede => 0,
        CategoriaPonto.candidato => 1,
        CategoriaPonto.ponto => 2,
      };

  Marker _marcador(MapPoint ponto) {
    const tam = MapStyles.markerSize;
    final Widget forma = switch (ponto.categoria) {
      CategoriaPonto.ponto => DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _cor(ponto),
            border: Border.all(color: MapStyles.bordaMarcador, width: 1.5),
          ),
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
              color: _cor(ponto),
              border: Border.all(color: MapStyles.bordaMarcador, width: 1),
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
