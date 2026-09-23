import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/reset_password_screen.dart';

/// Ações do menu de conta, usadas tanto pelo dropdown web
/// ([AccountMenuButton]) quanto pelo bottom sheet mobile
/// (`showAccountMenu`). Mantendo a lógica aqui, as duas apresentações
/// nunca divergem no que fazem — só em como aparecem na tela.
void openResetPassword(BuildContext context, {bool fromLogin = false}) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ResetPasswordScreen(fromLogin: fromLogin)),
  );
}

void handleLogout(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}