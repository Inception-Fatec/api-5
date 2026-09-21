import 'package:flutter/material.dart';

import '../app_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import 'map_screen.dart';
import 'new_project_screen.dart';
import 'projects_screen.dart';
import 'reset_password_screen.dart';
import '../navigation/bottom_nav_bar.dart' show showAccountMenu;

/// Login screen — tela de pré-autenticação: sem navbar em nenhuma
/// plataforma (web e mobile ficam idênticos aqui; a ausência de nav
/// chrome é simétrica, então não quebra a paridade). Card centralizado
/// com largura máxima de ~390px funciona igual em qualquer largura de
/// tela.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isLoading = false);

    // Login bem-sucedido: entra no AppShell, que a partir daqui é o
    // único lugar que decide navbar web / bottom nav mobile para as
    // três abas principais. O item "Login" do nav sempre abre o menu
    // de conta (Reset Password / Logout) — nunca volta pra esta tela.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AppShell(
          tabs: const [
            ProjectsScreen(),
            NewProjectScreen(),
            MapScreen(),
          ],
          onLoginTap: (ctx) => showAccountMenu(ctx),
        ),
      ),
    );
  }

  void _handleForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ResetPasswordScreen(fromLogin: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      card: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/logo.png', height: 40),
          const SizedBox(height: 16),
                const Text(
                  'ENTERPRISE SUPPLY CHAIN PLATFORM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 40),
                AuthTextField(
                  label: 'Email address',
                  hint: 'name@tecsys.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                AuthTextField(
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: true,
                  controller: _passwordController,
                  trailing: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _handleForgotPassword,
                    child: const Text(
                      'Forgot?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (v) => setState(() => _rememberMe = v ?? false),
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Remember for 30 days',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                  ),
                ),
          const SizedBox(height: 28),
          const _StatusFooter(),
        ],
      ),
    );
  }
}

/// Rodapé "🟢 Systems Operational   v24.2 Enterprise", no lugar do
/// badge de SSO anterior.
class _StatusFooter extends StatelessWidget {
  const _StatusFooter();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        const Text('Systems Operational', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(width: 16),
        const Text('v24.2 Enterprise', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}