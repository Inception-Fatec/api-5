import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/point_markers_layer.dart';

/// Legenda do mapa: no zoom afastado, as faixas das bolhas; de perto, a
/// cor e o formato de cada papel no cálculo (#TG-92).
class MapLegend extends StatelessWidget {
  final bool agrupado;

  const MapLegend({super.key, this.agrupado = false});

  static const _tensoes = [
    ('ALTO', 'Alta tensão'),
    ('MEDIO', 'Média tensão'),
    ('BAIXO', 'Baixa tensão'),
  ];

  static Widget _linha(Widget marca, String rotulo) => Padding(
        padding: const EdgeInsets.only(top: MapStyles.legendRowGap),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: MapStyles.legendDotSize,
              height: MapStyles.legendDotSize,
              child: Center(child: marca),
            ),
            const SizedBox(width: MapStyles.legendDotGap),
            Text(rotulo, style: MapStyles.legendLabel),
          ],
        ),
      );

  static Widget _bolinha(Color cor) => Container(
        width: MapStyles.legendDotSize,
        height: MapStyles.legendDotSize,
        decoration: BoxDecoration(shape: BoxShape.circle, color: cor),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: MapStyles.coordsPadding,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(MapStyles.coordsBgOpacity),
        borderRadius: MapStyles.coordsRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: MapStyles.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (agrupado) ...[
            Text('PONTOS A COBRIR NA BOLHA', style: MapStyles.coordsTitle),
            const SizedBox(height: 3),
            for (final (_, c, r) in MapStyles.clusterFaixas)
              _linha(_bolinha(c), r),
          ] else ...[
            Text('PONTO A COBRIR (TENSÃO)', style: MapStyles.coordsTitle),
            const SizedBox(height: 3),
            for (final (l, r) in _tensoes)
              _linha(_bolinha(MapStyles.corDaTensao(l)), r),
            const SizedBox(height: 6),
            Text('OUTROS', style: MapStyles.coordsTitle),
            const SizedBox(height: 3),
            _linha(
              Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: MapStyles.legendDotSize * 0.75,
                  height: MapStyles.legendDotSize * 0.75,
                  decoration: BoxDecoration(
                    color: MapStyles.corCandidato,
                    border: Border.all(
                        color: PointMarkersLayer.bordaCandidato, width: 1),
                  ),
                ),
              ),
              'Candidato a gateway',
            ),
            _linha(
              Container(
                width: MapStyles.legendDotSize * 0.8,
                height: MapStyles.legendDotSize * 0.8,
                color: MapStyles.corRede,
              ),
              'Rede elétrica',
            ),
          ],
        ],
      ),
    );
  }
}
