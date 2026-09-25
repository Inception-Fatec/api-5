import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../services/auth_service.dart';
import '../navigation/bottom_nav_bar.dart' show showAccountMenu;
import 'login_screen.dart';

/// Primeira tela do app — usar como `home:` do MaterialApp no lugar de
/// `LoginScreen()` direto.
///
/// Corrige o reset de sessão no F5 (Flutter Web): um reload de página
/// zera toda a memória do Dart (AuthService volta com tudo `null`), só
/// o que está persistido (TokenStorage → flutter_secure_storage, que
/// no web usa localStorage) sobrevive. Aqui a gente espera
/// [AuthService.restoreSession] terminar de ler esse storage antes de
/// decidir se mostra o [AppShell] (sessão restaurada) ou o
/// [LoginScreen] (sem sessão salva / token expirado).
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    await AuthService.instance.restoreSession();
    if (!mounted) return;
    setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!AuthService.instance.isAuthenticated) {
      return const LoginScreen();
    }

    // Sessão restaurada — mesma lista de tabs que o login normal monta
    // (RN04: Users só pra ADM), agora centralizada em AppShell.tabsFor
    // pra não duplicar essa lógica entre LoginScreen e aqui.
    final isAdmin = AuthService.instance.role == 'ADM';
    return AppShell(
      tabs: AppShell.tabsFor(isAdmin),
      onLoginTap: (ctx) => showAccountMenu(ctx),
    );
  }
}