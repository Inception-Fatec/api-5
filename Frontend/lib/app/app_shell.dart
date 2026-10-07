import 'package:flutter/material.dart';

import 'package:tecsys_app/features/auth/data/services/auth_service.dart';
import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/app/navigation/bottom_nav_bar.dart';
import 'package:tecsys_app/app/navigation/top_nav_bar.dart';
import 'package:tecsys_app/app/navigation/nav_items.dart';
import 'package:tecsys_app/features/projects/ui/screens/projects_screen.dart';
import 'package:tecsys_app/features/users/ui/screens/users_screen.dart';

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
/// (Login, que nunca é uma aba) — use [AppShell.tabsFor] pra montar
/// essa lista corretamente em vez de escrevê-la à mão de novo.
class AppShell extends StatefulWidget {
  static const webBreakpoint = 900.0;

  final List<Widget>
      tabs; // uma entrada por item de NavItems.forRole(role), exceto Login
  final void Function(BuildContext context)
      onLoginTap; // ação especial: abre o account menu

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

  /// Lista de tabs pro role informado — única fonte usada tanto depois
  /// de um login bem-sucedido (LoginScreen._goToAppShell) quanto ao
  /// restaurar uma sessão existente no boot do app (SplashGate), pra
  /// nunca divergir da lista de NavItems.forRole (RN04 — Users só
  /// entra pra ADM nos dois casos).
  ///
  /// "Novo Projeto" deixou de ser uma aba própria — virou um botão
  /// dentro de "Projetos" (que abre o popup direto), então não entra
  /// mais nessa lista.
  static List<Widget> tabsFor(bool isAdmin) {
    return [
      const ProjectsScreen(),
      if (isAdmin) const UsersScreen(),
    ];
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void _handleNavTap(
      List<({IconData icon, String label})> navItems, int index) {
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

        return _AppShellScope(
            goToTab: (i) => setState(() => _currentIndex = i), child: scaffold);
      },
    );
  }
}

class _AppShellScope extends InheritedWidget {
  final ValueChanged<int> goToTab;

  const _AppShellScope({required this.goToTab, required super.child});

  @override
  bool updateShouldNotify(_AppShellScope oldWidget) =>
      goToTab != oldWidget.goToTab;
}
