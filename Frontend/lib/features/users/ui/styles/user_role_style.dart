import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/users/data/models/user_model.dart';

/// Rótulos, ícones e cores de cada perfil de usuário (só apresentação:
/// o model guarda apenas o [UserRoleType] cru).
class UserRoleStyle {
  UserRoleStyle._();

  static bool _isAdmin(UserRoleType role) => role == UserRoleType.adm;

  /// Nome completo do perfil ("Administrador" / "Usuário").
  static String label(UserRoleType role) =>
      _isAdmin(role) ? 'Administrador' : 'Usuário';

  /// Texto curto do selo ("Admin" / "Usuário").
  static String badge(UserRoleType role) =>
      _isAdmin(role) ? 'Admin' : 'Usuário';

  static IconData icon(UserRoleType role) => _isAdmin(role)
      ? Icons.admin_panel_settings_outlined
      : Icons.person_outline;

  static Color color(UserRoleType role) =>
      _isAdmin(role) ? AppColors.primary : AppColors.textSecondary;

  /// Fundo suave do selo e do avatar (a [color] a 12% de opacidade).
  static Color softColor(UserRoleType role) =>
      _isAdmin(role) ? AppColors.primarySoft : AppColors.neutralSoft;
}
