import 'package:flutter/material.dart';

import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

/// Linha "rótulo — valor" do detalhe de um ponto.
class PointDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const PointDetailRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MapStyles.detailRowPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: MapStyles.detailRowLabel),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: MapStyles.detailRowValue,
            ),
          ),
        ],
      ),
    );
  }
}
