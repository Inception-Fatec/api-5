import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/data/constants/point_labels.dart';
import 'package:tecsys_app/features/map/data/models/map_point.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

/// Cabeçalho do detalhe: nome (ou id), id, camada e botão de fechar.
class PointDetailHeader extends StatelessWidget {
  final MapPoint point;
  final VoidCallback onClose;

  const PointDetailHeader({
    super.key,
    required this.point,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final id = point.id ?? '-';
    final layer = point.layer;
    final nome = point.properties['nome']?.toString();

    return Row(
      children: [
        Container(
          width: MapStyles.detailIconBoxSize,
          height: MapStyles.detailIconBoxSize,
          decoration: const BoxDecoration(
              color: AppColors.infoBlueBg, borderRadius: AppRadius.sm),
          child: const Icon(
            Icons.location_on_outlined,
            size: MapStyles.detailIconSize,
            color: AppColors.infoBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nome ?? id, style: MapStyles.detailTitle),
              if (nome != null) Text(id, style: AppTextStyles.caption),
              if (layer != null)
                Text(PointLabels.layerLabel(layer),
                    style: AppTextStyles.caption),
            ],
          ),
        ),
        IconButton(icon: const Icon(Icons.close), onPressed: onClose),
      ],
    );
  }
}
