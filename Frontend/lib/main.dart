import 'package:flutter/material.dart';
import 'screens/users_screen.dart'; // <--- Import da sua tela
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
      home: const UsersScreen(), // <--- Abre direto a tela de usuários
    );
  }
}