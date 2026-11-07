import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/point_markers_layer.dart';

class MapLegend extends StatelessWidget {
  final bool agrupado;

  const MapLegend({super.key, this.agrupado = false});

  static const _itens = [
    ('ALTO', 'Alta tensão'),
    ('MEDIO', 'Média tensão'),
    ('BAIXO', 'Baixa tensão'),
    ('SUB', 'Subestação'),
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

  static Widget _bolinha(Color cor, {double fator = 1}) => Container(
        width: MapStyles.legendDotSize * fator,
        height: MapStyles.legendDotSize * fator,
        decoration: BoxDecoration(shape: BoxShape.circle, color: cor),
      );

  @override
  Widget build(BuildContext context) {
    final neutro = AppColors.textSecondary;
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
            Text('TIPO', style: MapStyles.coordsTitle),
            const SizedBox(height: 3),
            _linha(_bolinha(neutro), 'Ponto a cobrir'),
            _linha(
              Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: MapStyles.legendDotSize * 0.75,
                  height: MapStyles.legendDotSize * 0.75,
                  decoration: BoxDecoration(
                    color: neutro,
                    border: Border.all(
                        color: PointMarkersLayer.bordaCandidato, width: 1),
                  ),
                ),
              ),
              'Local para gateway',
            ),
            _linha(
              _bolinha(neutro.withOpacity(PointMarkersLayer.opacidadeRede),
                  fator: 0.55),
              'Rede elétrica',
            ),
            const SizedBox(height: 6),
            Text('TENSÃO', style: MapStyles.coordsTitle),
            const SizedBox(height: 3),
            for (final (l, r) in _itens) _linha(_bolinha(MapStyles.layerColor(l)), r),
          ],
        ],
      ),
    );
  }
}
