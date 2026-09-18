import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'new_project_screen.dart';
import 'projects_screen.dart';
import 'reset_password_screen.dart';

/// Dev-only screen picker. NOT part of the Figma design — just a way
/// to jump between screens while testing, without editing main.dart
/// every time. Remove before the real submission/demo.
class DevMenuScreen extends StatelessWidget {
  const DevMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dev menu — escolha a tela')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _ScreenButton(
            label: 'Login',
            builder: (_) => const LoginScreen(),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ScreenButton(
            label: 'Projects',
            builder: (_) => const ProjectsScreen(),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ScreenButton(
            label: 'Map',
            builder: (_) => const MapScreen(),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ScreenButton(
            label: 'New Project',
            builder: (_) => const NewProjectScreen(),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ScreenButton(
            label: 'Reset Password',
            builder: (_) => const ResetPasswordScreen(),
          ),
        ],
      ),
    );
  }
}

class _ScreenButton extends StatelessWidget {
  final String label;
  final WidgetBuilder builder;

  const _ScreenButton({required this.label, required this.builder});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: builder));
        },
        child: Text(label),
      ),
    );
  }
}
