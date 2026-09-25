import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

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
      home: const LoginScreen(),
    );
  }
}