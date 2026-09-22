import 'package:flutter/material.dart';

/// Fonte única dos itens de navegação. BottomNavBar, TopNavBar e o
/// AppShell leem daqui — mudar um label/ícone muda nos dois lugares
/// (paridade web/mobile).
///
/// RN04 (US-34): "Users" só aparece pra quem está logado como ADM —
/// por isso deixou de ser uma lista `const` fixa e virou [forRole],
/// que recebe o role atual (AuthService.instance.role) e monta a
/// lista certa. "Login"/conta continua sempre por último: o AppShell
/// trata o último índice como ação especial (abre o menu de conta),
/// nunca uma aba — isso não muda com o Users entrando no meio.
class NavItems {
  NavItems._();

  static const _projects = (icon: Icons.folder_outlined, label: 'Projects');
  static const _newProject = (icon: Icons.add_circle_outline, label: 'New Project');
  static const _mapView = (icon: Icons.location_on_outlined, label: 'Map View');
  static const _users = (icon: Icons.people_outline, label: 'Users');
  static const _login = (icon: Icons.lock_outline, label: 'Login');

  static List<({IconData icon, String label})> forRole(String? role) {
    return [
      _projects,
      _newProject,
      _mapView,
      if (role == 'ADM') _users,
      _login,
    ];
  }
}