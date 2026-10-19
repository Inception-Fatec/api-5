import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

/// Botão redondo flutuante sobre o mapa (ex: liga/desliga o relevo).
class MapFloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool ativo;

  const MapFloatingButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.ativo = false,
  });

  @override
  Widget build(BuildContext context) {
    final botao = Material(
      color: ativo ? AppColors.primary : AppColors.surface,
      shape: const CircleBorder(),
      elevation: MapStyles.floatingElevation,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: MapStyles.floatingPadding,
          child: Icon(
            icon,
            size: MapStyles.floatingIconSize,
            color: ativo ? AppColors.onPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
    return tooltip == null ? botao : Tooltip(message: tooltip, child: botao);
  }
}
