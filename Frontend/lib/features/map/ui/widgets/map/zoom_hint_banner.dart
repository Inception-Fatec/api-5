import 'package:flutter/material.dart';

import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

/// Aviso sobre o mapa quando o zoom está baixo demais para buscar pontos.
class ZoomHintBanner extends StatelessWidget {
  const ZoomHintBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: MapStyles.zoomHintPadding,
      decoration: MapStyles.zoomHintDecoration,
      child: const Text(
        'Dá mais zoom pra ver os pontos dessa área.',
        textAlign: TextAlign.center,
        style: MapStyles.zoomHintText,
      ),
    );
  }
}
