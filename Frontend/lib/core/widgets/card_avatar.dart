import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Avatar redondo do topo dos cards de listagem: iniciais ou ícone em
/// branco sobre a cor [color].
class CardAvatar extends StatelessWidget {
  final Color color;
  final String? initials;
  final IconData? icon;

  const CardAvatar({super.key, required this.color, this.initials, this.icon})
      : assert(initials != null || icon != null);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: AppCardStyles.avatarRadius,
      backgroundColor: color,
      child: initials != null
          ? Text(initials!, style: AppCardStyles.avatarText)
          : Icon(icon,
              size: AppCardStyles.avatarIconSize, color: AppColors.onPrimary),
    );
  }
}
