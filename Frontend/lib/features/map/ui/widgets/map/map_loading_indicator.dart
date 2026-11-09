import 'package:flutter/material.dart';

import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

/// Indicador discreto de "buscando pontos", centralizado no topo do mapa.
class MapLoadingIndicator extends StatelessWidget {
  const MapLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: MapStyles.loadingSize,
        height: MapStyles.loadingSize,
        child: CircularProgressIndicator(strokeWidth: MapStyles.loadingStroke),
      ),
    );
  }
}
