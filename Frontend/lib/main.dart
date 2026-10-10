import 'package:flutter/material.dart';
import 'package:tecsys_app/features/auth/ui/screens/splash_gate.dart';
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
      home: const SplashGate(),
    );
  }
}
