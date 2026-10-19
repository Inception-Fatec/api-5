import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

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
          const Text('TENSÃO', style: MapStyles.coordsTitle),
          const SizedBox(height: 3),
          for (final (layer, rotulo) in _itens)
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
                      color: MapStyles.layerColor(layer),
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