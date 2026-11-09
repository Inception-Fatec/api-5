import 'package:flutter/material.dart';

import 'package:tecsys_app/features/auth/data/services/auth_service.dart';
import 'package:tecsys_app/features/auth/ui/screens/login_screen.dart';

/// Navigator do app inteiro — vai no `navigatorKey:` do MaterialApp. Com
/// ele dá para voltar ao login de qualquer tela quando a sessão expira.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Liga o aviso de sessão expirada: quando o [AuthService] desloga por
/// token vencido, fecha todas as telas, abre o login e mostra o aviso.
/// Chamado uma vez pelo SplashGate.
void configurarExpiracaoDeSessao() {
  AuthService.instance.onSessaoExpirada = () {
    final navegador = appNavigatorKey.currentState;
    if (navegador == null) return;
    navegador.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    ScaffoldMessenger.maybeOf(navegador.context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Sua sessão expirou. Faça login novamente.'),
      ));
  };
}
