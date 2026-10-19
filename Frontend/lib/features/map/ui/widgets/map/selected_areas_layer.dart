import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/data/models/selected_area.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

class SelectedAreasLayer extends StatelessWidget {
  final List<SelectedArea> areas;
  final int? selecionada;
  final ValueListenable<int?> destaque;

  const SelectedAreasLayer({
    super.key,
    required this.areas,
    required this.destaque,
    this.selecionada,
  });

  @override
  Widget build(BuildContext context) {
    if (areas.isEmpty) return const SizedBox.shrink();

    final corSelecionada = MapStyles.areaSelectedColor;
    final temSelecionada = selecionada != null && selecionada! < areas.length;

    return ValueListenableBuilder<int?>(
      valueListenable: destaque,
      builder: (context, aceso, _) => PolygonLayer(
        polygons: [
          for (var i = 0; i < areas.length; i++)
            if (i != selecionada)
              Polygon(
                points: areas[i].corners,
                color:
                    AppColors.primary.withOpacity(MapStyles.areaFillOpacity),
                borderColor:
                    AppColors.primary.withOpacity(MapStyles.areaBorderOpacity),
                borderStrokeWidth: MapStyles.areaBorderWidth,
              ),
          if (temSelecionada)
            Polygon(
              points: areas[selecionada!].corners,
              color: corSelecionada
                  .withOpacity(MapStyles.areaSelectedFillOpacity),
              borderColor: corSelecionada,
              borderStrokeWidth: MapStyles.areaSelectedBorderWidth,
            ),
          if (aceso != null && aceso < areas.length)
            Polygon(
              points: areas[aceso].corners,
              color: corSelecionada
                  .withOpacity(MapStyles.areaHighlightFillOpacity),
              borderColor: corSelecionada,
              borderStrokeWidth: MapStyles.areaHighlightBorderWidth,
            ),
        ],
      ),
    );
  }
}