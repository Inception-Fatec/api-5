import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

class MapLegend extends StatelessWidget {
  final bool agrupado;

  const MapLegend({super.key, this.agrupado = false});

  static const _itens = [
    ('ALTO', 'Alta tensão'),
    ('MEDIO', 'Média tensão'),
    ('BAIXO', 'Baixa tensão'),
    ('SUB', 'Subestação'),
  ];

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
          Text(agrupado ? 'PONTOS NA BOLHA' : 'TENSÃO',
              style: MapStyles.coordsTitle),
          const SizedBox(height: 3),
          for (final (cor, rotulo) in agrupado
              ? [for (final (_, c, r) in MapStyles.clusterFaixas) (c, r)]
              : [for (final (l, r) in _itens) (MapStyles.layerColor(l), r)])
            Padding(
              padding: const EdgeInsets.only(top: MapStyles.legendRowGap),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: MapStyles.legendDotSize,
                    height: MapStyles.legendDotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cor,
                    ),
                  ),
                  const SizedBox(width: MapStyles.legendDotGap),
                  Text(rotulo, style: MapStyles.legendLabel),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
