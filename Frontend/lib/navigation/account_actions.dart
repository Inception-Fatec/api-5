import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/reset_password_screen.dart';
import '../services/auth_service.dart';

/// Ações do menu de conta, usadas tanto pelo dropdown web
/// ([AccountMenuButton]) quanto pelo bottom sheet mobile
/// (`showAccountMenu`). Mantendo a lógica aqui, as duas apresentações
/// nunca divergem no que fazem — só em como aparecem na tela.
void openResetPassword(BuildContext context, {bool fromLogin = false}) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ResetPasswordScreen(fromLogin: fromLogin)),
  );
}

Future<void> handleLogout(BuildContext context) async {
  await AuthService.instance.logout();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}