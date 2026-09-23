import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';

/// Reset Password — tela de fluxo de autenticação, igual à
/// [LoginScreen]: sem navbar em nenhuma plataforma. Antes ela
/// reimplementava BottomNavBar + navegação pras 3 abas principais, mas
/// isso já é papel do AppShell (e nem se aplica aqui, já que esta
/// tela é sempre empilhada com Navigator.push, nunca uma aba).
///
/// [fromLogin] só controla o texto/ação do botão de voltar: a tela é
/// alcançável tanto pelo "Forgot password?" do login (usuário ainda
/// deslogado) quanto pelo menu de conta dentro do app (usuário
/// trocando a senha já logado) — nos dois casos o botão apenas fecha
/// esta tela (`pop`), voltando pra onde o usuário estava.
class ResetPasswordScreen extends StatefulWidget {
  final bool fromLogin;

  const ResetPasswordScreen({super.key, this.fromLogin = false});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      card: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.lock_reset, size: 28, color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Tecsys',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(6)),
                      child: const Text('ID',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Reset Password',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Enter your corporate email to receive password reset instructions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.45),
                ),
                const SizedBox(height: AppSpacing.xl),
                AuthTextField(
                  label: 'Corporate Email',
                  hint: 'name@company.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline,
                  trailing: const Text('SSO Enabled', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Send Reset Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 19),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back, size: 18, color: AppColors.textPrimary),
                        const SizedBox(width: 8),
                        Text(
                          widget.fromLogin ? 'Back to Login' : 'Back',
                          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.shield_outlined, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Tecsys Identity & Access Management v4.2',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}