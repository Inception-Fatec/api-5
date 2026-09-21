import 'package:flutter/material.dart';

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
class AppShell extends StatefulWidget {
  static const webBreakpoint = 900.0;

  final List<Widget> tabs; // uma entrada por item de NavItems.all, exceto Login
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

  void _handleNavTap(int index) {
    // O último item (Login/Account) nunca vira uma aba do IndexedStack —
    // ele sempre dispara a ação especial, em qualquer plataforma.
    if (index == NavItems.all.length - 1) {
      widget.onLoginTap(context);
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
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
                    TopNavBar(currentIndex: _currentIndex, onNavTap: _handleNavTap),
                    Expanded(child: body),
                  ],
                ),
              )
            : Scaffold(
                backgroundColor: AppColors.background,
                body: SafeArea(child: body),
                bottomNavigationBar: BottomNavBar(
                  currentIndex: _currentIndex,
                  onTap: _handleNavTap,
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