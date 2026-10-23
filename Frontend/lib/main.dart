import 'package:flutter/material.dart';
import 'package:tecsys_app/features/auth/ui/screens/login_screen.dart';
import 'package:tecsys_app/features/etl_geodados/etl_geodados_screen.dart';
import 'package:tecsys_app/core/theme/app_theme.dart';

void main() {
  runApp(const TecsysApp());
}

class TecsysApp extends StatelessWidget {
  const TecsysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tecsys',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Define a tela de Login como a inicial ao iniciar o app
      home: const LoginScreen(),
      routes: {
        '/etl': (context) => const EtlGeodadosScreen(),
      },
    );
  }
}