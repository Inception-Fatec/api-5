import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Botão principal de ação de uma tela ("Novo Projeto", "Novo
/// Usuário"). [full] = largura total (mobile).
class PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool full;

  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.full,
  });

  static const _height = 52.0;
  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final botao = ElevatedButton(
      onPressed: onPressed,
      style: AppButtonStyles.primary(
        padding: EdgeInsets.symmetric(horizontal: full ? 0 : 22, vertical: 16),
        flat: true,
      ),
      child: Row(
        mainAxisAlignment:
            full ? MainAxisAlignment.center : MainAxisAlignment.start,
        mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: _iconSize),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: AppTextStyles.buttonTextLarge),
        ],
      ),
    );
    return full
        ? SizedBox(width: double.infinity, height: _height, child: botao)
        : botao;
  }
}
