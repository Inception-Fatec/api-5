import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

/// Uma ferramenta da [MapToolbar].
class MapToolbarItem {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool ativo;

  const MapToolbarItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.ativo = false,
  });
}

class MapToolbar extends StatelessWidget {
  final List<MapToolbarItem> itens;

  const MapToolbar({super.key, required this.itens});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: MapStyles.toolbarPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: MapStyles.toolbarRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: MapStyles.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < itens.length; i++) ...[
            if (i > 0) const SizedBox(height: MapStyles.toolbarItemGap),
            _Ferramenta(item: itens[i]),
          ],
        ],
      ),
    );
  }
}

class _Ferramenta extends StatelessWidget {
  final MapToolbarItem item;

  const _Ferramenta({required this.item});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.tooltip,
      child: Material(
        color: item.ativo
            ? AppColors.primary.withOpacity(MapStyles.toolbarActiveBgOpacity)
            : Colors.transparent,
        borderRadius: MapStyles.toolbarItemRadius,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: MapStyles.toolbarItemRadius,
          child: SizedBox(
            width: MapStyles.toolbarItemSize,
            height: MapStyles.toolbarItemSize,
            child: Icon(
              item.icon,
              size: MapStyles.toolbarIconSize,
              color: item.ativo ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}