import 'package:flutter/material.dart';

import 'package:tecsys_app/app/app_shell.dart';
import 'package:tecsys_app/features/auth/data/services/auth_service.dart';
import 'package:tecsys_app/app/navigation/account_menu_sheet.dart'
    show showAccountMenu;
import 'package:tecsys_app/features/auth/ui/screens/login_screen.dart';
import 'package:tecsys_app/features/auth/ui/session_expiry.dart';
import 'package:tecsys_app/features/auth/ui/widgets/first_access_modal.dart';

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
    configurarExpiracaoDeSessao();
    _restore();
  }

  Future<void> _restore() async {
    await AuthService.instance.restoreSession();
    if (!mounted) return;
    setState(() => _checked = true);

    // RN02: F5 antes de trocar a senha do primeiro acesso. Igual ao
    // login: o modal vem antes do app (senão as telas carregam e o
    // backend recusa tudo com 403 até a troca).
    final auth = AuthService.instance;
    if (auth.isAuthenticated && auth.mustChangePassword) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const FirstAccessModal(),
        );
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!AuthService.instance.isAuthenticated) {
      return const LoginScreen();
    }

    // Senha do primeiro acesso ainda não trocada: só o modal (ver _restore).
    if (AuthService.instance.mustChangePassword) {
      return const Scaffold();
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
