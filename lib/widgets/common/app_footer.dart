import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Rodapé padrão do app: uma barrinha fina e única, com uma linha
/// separadora em cima — não um bloco de texto que pode quebrar em
/// duas linhas. Usado no fim de qualquer página, web ou mobile, pra
/// manter o mesmo conteúdo nas duas plataformas.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEDEFF3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Flexible(
            child: Text(
              '© 2024 Tecsys Inc. Enterprise Supply Chain Velocity. All rights reserved.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Text(
            'Privacy Policy   Terms of Service   System Status',
            style: TextStyle(fontSize: 11, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}