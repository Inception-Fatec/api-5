import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Botão quadrado "+" ao lado dos campos que adicionam valores aos
/// filtros.
class FilterAddButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final BorderRadius radius;

  const FilterAddButton({
    super.key,
    required this.onTap,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        decoration:
            BoxDecoration(color: AppColors.infoBlueBg, borderRadius: radius),
        child: const Icon(Icons.add, color: AppColors.infoBlue),
      ),
    );
  }
}
