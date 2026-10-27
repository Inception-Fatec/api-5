import 'package:flutter/material.dart';
import 'package:tecsys_app/features/auth/ui/screens/splash_gate.dart';
import 'package:tecsys_app/features/etl_geodados/etl_geodados_screen.dart';
import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/auth/ui/session_expiry.dart';

void main() {
  runApp(const TecsysApp());
}

class TecsysApp extends StatelessWidget {
  const TecsysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tecsys',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Tocar fora de um campo de texto tira o foco e fecha o teclado
      // (celular/tablet). Envolve o Navigator, então vale para telas e diálogos.
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
      // SplashGate decide entre restaurar a sessão salva ou mostrar o login.
      home: const SplashGate(),
      routes: {
        '/etl': (context) => const EtlGeodadosScreen(),
      },
    );
  }
}