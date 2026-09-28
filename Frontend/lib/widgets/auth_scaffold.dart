import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common/app_footer.dart';

/// Casca usada por [LoginScreen] e [ResetPasswordScreen]. Diferente
/// do AppShell (que decide navbar completa web vs. bottom nav
/// mobile), aqui não existe ramificação por plataforma: é a mesma
/// árvore de widgets nas duas — topo com só a logo (sem links de
/// navegação, sem avatar — o usuário ainda não está "dentro" do
/// app), o card de conteúdo centralizado com borda pra se destacar
/// do fundo, e o rodapé padrão embaixo.
class AuthScaffold extends StatelessWidget {
  final Widget card;

  const AuthScaffold({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const _AuthTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE4E8EF)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: card,
                    ),
                  ),
                ),
              ),
            ),
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}

class _AuthTopBar extends StatelessWidget {
  const _AuthTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: Color(0xFFEDEFF3))),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub, color: AppColors.primary, size: 24),
          SizedBox(width: 8),
          Text('Tecsys', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}