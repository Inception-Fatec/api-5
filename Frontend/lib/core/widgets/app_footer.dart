import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Rodapé padrão do app: uma barrinha fina e única, com uma linha
/// separadora em cima — não um bloco de texto que pode quebrar em
/// duas linhas. Usado no fim de qualquer página, web ou mobile, pra
/// manter o mesmo conteúdo nas duas plataformas. Sem links: o app não
/// tem política de privacidade, termos nem página de status.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Text(
        '© ${DateTime.now().year} Tecsys · Projeto acadêmico Fatec (API 5º semestre)',
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
