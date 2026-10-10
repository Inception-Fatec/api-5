import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

/// Botão redondo de voltar, no canto superior esquerdo do mapa.
class MapBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const MapBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: MapStyles.backButtonPadding,
        child: IconButton(
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            shape: const CircleBorder(),
          ),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
