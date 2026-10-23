import 'package:flutter/material.dart';
import 'package:tecsys_app/features/auth/ui/screens/splash_gate.dart';
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
      home: const SplashGate(),
    );
  }
}
