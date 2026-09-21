import 'package:flutter/material.dart';

/// Fonte única dos itens de navegação. Hoje BottomNavBar e o
/// _TopNavBar de cada tela mantinham essa lista duplicada — se alguém
/// mudasse um label ou ícone, tinha que lembrar de mudar nos dois
/// lugares. Agora é uma constante só, referenciada pelos dois widgets
/// de navegação e pelo AppShell.
class NavItems {
  NavItems._();

  static const all = [
    (icon: Icons.folder_outlined, label: 'Projects'),
    (icon: Icons.add_circle_outline, label: 'New Project'),
    (icon: Icons.location_on_outlined, label: 'Map View'),
    (icon: Icons.lock_outline, label: 'Login'),
  ];
}