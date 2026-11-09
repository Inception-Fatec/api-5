import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

class MapCoordinatesPanel extends StatelessWidget {
  final String titulo;
  final List<List<(String, String)>> linhas;

  const MapCoordinatesPanel({
    super.key,
    required this.titulo,
    required this.linhas,
  });

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
          Text(titulo, style: MapStyles.coordsTitle),
          const SizedBox(height: 3),
          for (final linha in linhas)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < linha.length; i++) ...[
                  if (i > 0) const SizedBox(width: MapStyles.coordsColumnGap),
                  SizedBox(
                    width: MapStyles.coordsLabelWidth,
                    child: Text(linha[i].$1, style: MapStyles.coordsLabel),
                  ),
                  Text(linha[i].$2, style: MapStyles.coordsValue),
                ],
              ],
            ),
        ],
      ),
    );
  }
}