import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/data/constants/point_labels.dart';
import 'package:tecsys_app/features/map/data/models/map_point.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/point_detail_header.dart';
import 'package:tecsys_app/features/map/ui/widgets/map/point_detail_row.dart';

/// Painel inferior com os dados de um ponto ao tocar no marcador.
class PointDetailSheet extends StatelessWidget {
  final MapPoint point;

  const PointDetailSheet({super.key, required this.point});

  static Future<void> mostrar(BuildContext context, {required MapPoint point}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (context) => PointDetailSheet(point: point),
    );
  }

  @override
  Widget build(BuildContext context) {
    final props = point.properties;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PointDetailHeader(
              point: point,
              onClose: () => Navigator.pop(context),
            ),
            const Divider(height: 24),
            // Na ordem de PointLabels.fields, pulando valores nulos
            // (id, camada e nome já estão no cabeçalho).
            ...PointLabels.fields.entries
                .where((e) => props[e.key] != null)
                .map((e) => PointDetailRow(
                      label: e.value,
                      value: '${props[e.key]}',
                    )),
          ],
        ),
      ),
    );
  }
}
