import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'navigation/bottom_nav_bar.dart';
import 'navigation/top_nav_bar.dart';
import 'navigation/nav_items.dart';

/// Ponto único de navegação do app. Decide web vs. mobile UMA vez,
/// mantém o índice da aba atual e troca o conteúdo com [IndexedStack]
/// — cada aba preserva seu estado (scroll, zoom do mapa, formulário
/// em andamento) em vez de ser reconstruída a cada troca.
///
/// As telas passadas em [tabs] NÃO devem ter Scaffold nem
/// bottomNavigationBar próprios — só o conteúdo.
///
/// [tabs] precisa estar na MESMA ordem e ter o MESMO tamanho de
/// `NavItems.forRole(AuthService.instance.role)` menos o último item
/// (Login, que nunca é uma aba) — é quem constrói o AppShell
/// (login_screen.dart) que decide incluir ou não UsersScreen conforme
/// o role, então os dois lados (tabs aqui, nav items lá embaixo)
/// ficam em sincronia por lerem o mesmo AuthService.instance.role.
class AppShell extends StatefulWidget {
  static const webBreakpoint = 900.0;

  final List<Widget> tabs; // uma entrada por item de NavItems.forRole(role), exceto Login
  final void Function(BuildContext context) onLoginTap; // ação especial: abre o account menu

  const AppShell({
    super.key,
    required this.tabs,
    required this.onLoginTap,
  });

  /// Permite que qualquer tela filha peça uma troca de aba:
  /// `AppShell.of(context)?.goToTab(1)`. Retorna null se não houver
  /// um AppShell ancestral (ex: tela usada fora dele em testes).
  static _AppShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppShellScope>();

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void _handleNavTap(List<({IconData icon, String label})> navItems, int index) {
    // O último item (Login/Account) nunca vira uma aba do IndexedStack —
    // ele sempre dispara a ação especial, em qualquer plataforma.
    if (index == navItems.length - 1) {
      widget.onLoginTap(context);
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Calculado uma vez por build a partir do role atual — RN04:
    // "Users" só entra na lista pra ADM (ver nav_items.dart).
    final navItems = NavItems.forRole(AuthService.instance.role);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth >= AppShell.webBreakpoint;

        final body = IndexedStack(
          index: _currentIndex,
          children: widget.tabs,
        );

        final scaffold = isWeb
            ? Scaffold(
                backgroundColor: AppColors.pageBg,
                body: Column(
                  children: [
                    TopNavBar(
                      currentIndex: _currentIndex,
                      navItems: navItems,
                      onNavTap: (i) => _handleNavTap(navItems, i),
                    ),
                    Expanded(child: body),
                  ],
                ),
              )
            : Scaffold(
                backgroundColor: AppColors.background,
                body: SafeArea(child: body),
                bottomNavigationBar: BottomNavBar(
                  currentIndex: _currentIndex,
                  navItems: navItems,
                  onTap: (i) => _handleNavTap(navItems, i),
                ),
              );

        return _AppShellScope(goToTab: (i) => setState(() => _currentIndex = i), child: scaffold);
      },
    );
  }
}

/// Deixa o AppShell "encontrável" por qualquer tela filha, via
/// `AppShell.of(context)?.goToTab(index)`. Assim um botão dentro de
/// uma aba (ex: "+ New Project" na ProjectsScreen) troca de aba pelo
/// IndexedStack do próprio Shell, em vez de empilhar uma nova rota —
/// o que também evita telas ficarem sem Material ancestral quando
/// empilhadas fora da árvore do Shell.
class _AppShellScope extends InheritedWidget {
  final ValueChanged<int> goToTab;

  const _AppShellScope({required this.goToTab, required super.child});

  @override
  bool updateShouldNotify(_AppShellScope oldWidget) => goToTab != oldWidget.goToTab;
}