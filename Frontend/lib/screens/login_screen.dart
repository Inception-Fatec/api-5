import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, SingleActivator;

import '../app_shell.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/first_access_modal.dart';
import '../navigation/account_actions.dart' show openResetPassword;
import 'new_project_screen.dart';
import 'projects_screen.dart';
import 'users_screen.dart';
import '../navigation/bottom_nav_bar.dart' show showAccountMenu;

/// Login screen — tela de pré-autenticação: sem navbar em nenhuma
/// plataforma (web e mobile ficam idênticos aqui; a ausência de nav
/// chrome é simétrica, então não quebra a paridade). Card centralizado
/// com largura máxima de ~390px funciona igual em qualquer largura de
/// tela.
///
/// Integrado com POST /api/v1/auth/login (task #52). O link "Forgot?"
/// já abre a ResetPasswordScreen (fromLogin: true) pra mostrar o
/// fluxo pronto — a tela em si ainda não bate numa rota de
/// recuperação por e-mail real, porque o backend não tem essa rota
/// ainda (o botão "Send Reset Link" de lá continua sem ação).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Não foi possível conectar ao servidor.';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    // RN02: primeiro acesso não navega no app sem antes trocar a
    // senha padrão — modal bloqueante da task #53.
    if (AuthService.instance.mustChangePassword) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const FirstAccessModal(),
      );
      if (!mounted) return;
    }

    _goToAppShell();
  }

  void _goToAppShell() {
    // Login bem-sucedido: entra no AppShell, que a partir daqui é o
    // único lugar que decide navbar web / bottom nav mobile para as
    // abas principais. O item "Login" do nav sempre abre o menu
    // de conta (Reset Password / Logout) — nunca volta pra esta tela.
    //
    // AppShell.tabsFor(isAdmin) é a mesma função que o SplashGate usa
    // ao restaurar uma sessão persistida (F5 na web) — garante que
    // login normal e sessão restaurada nunca montem tabs diferentes
    // (RN04: Users só entra pra ADM nos dois casos).
    final isAdmin = AuthService.instance.role == 'ADM';
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AppShell(
          tabs: [
            const ProjectsScreen(),
            const NewProjectScreen(),
            if (isAdmin) const UsersScreen(),
          ],
          onLoginTap: (ctx) => showAccountMenu(ctx),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      card: Shortcuts(
        // Enter em qualquer campo do form dispara o login — sem isso,
        // apertar Enter depois da senha não fazia nada.
        shortcuts: const <SingleActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                if (!_isLoading) _handleSignIn();
                return null;
              },
            ),
          },
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hub, color: AppColors.primary, size: 32),
              SizedBox(width: 8),
              Text('Tecsys', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
                const SizedBox(height: 40),
                AuthTextField(
                  label: 'E-mail',
                  hint: 'nome@tecsys.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                AuthTextField(
                  label: 'Senha',
                  hint: '••••••••',
                  obscureText: true,
                  controller: _passwordController,
                  trailing: ExcludeFocus(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => openResetPassword(context, fromLogin: true),
                      child: const Text(
                        'Esqueceu a senha?',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 13, color: Colors.red),
                  ),
                ],
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
                              Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                  ),
                ),
        ],
          ),
        ),
      ),
    );
  }
}