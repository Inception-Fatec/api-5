import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'auth_text_field.dart';

/// Modal de primeiro acesso — RN02: todo usuário recém-criado nasce
/// com must_change_password = true; aqui é onde ele troca a senha
/// padrão antes de poder navegar. Bloqueante por design (sem botão
/// de fechar, WillPopScope segura o back do Android): abrir via
/// showDialog(barrierDismissible: false, builder: (_) =>
/// const FirstAccessModal()) logo após um login com
/// AuthService.instance.mustChangePassword == true. Mesmo widget
/// serve web e mobile — showDialog já é responsivo nas duas.
class FirstAccessModal extends StatefulWidget {
  const FirstAccessModal({super.key});

  @override
  State<FirstAccessModal> createState() => _FirstAccessModalState();
}

class _FirstAccessModalState extends State<FirstAccessModal> {
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final newPassword = _newPasswordController.text;
    final confirm = _confirmController.text;

    // Mesma regra do ChangePasswordDto (@Size min = 6) — valida antes
    // de bater no backend pra dar feedback imediato.
    if (newPassword.length < 6) {
      setState(() => _error = 'A senha deve ter no mínimo 6 caracteres.');
      return;
    }
    if (newPassword != confirm) {
      setState(() => _error = 'As senhas não coincidem.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService.instance.changePassword(newPassword);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _error = 'Não foi possível conectar ao servidor.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Defina sua nova senha',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Este é seu primeiro acesso. Por segurança, defina uma nova senha antes de continuar.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),
                AuthTextField(
                  label: 'Nova senha',
                  hint: '••••••••',
                  obscureText: true,
                  controller: _newPasswordController,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Confirmar nova senha',
                  hint: '••••••••',
                  obscureText: true,
                  controller: _confirmController,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
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
                        : const Text('Confirmar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}