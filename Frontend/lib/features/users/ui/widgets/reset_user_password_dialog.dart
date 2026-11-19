import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/auth/ui/widgets/auth_text_field.dart';
import 'package:tecsys_app/features/users/data/models/user_model.dart';

/// Pede a senha temporária de quem esqueceu a senha. Devolve a senha, ou
/// null se o administrador cancelar. Mesmo visual do "Novo usuário".
Future<String?> showResetUserPasswordDialog(BuildContext context, AppUser member) {
  return showDialog<String>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ResetUserPasswordDialog(member: member),
      ),
    ),
  );
}

class ResetUserPasswordDialog extends StatefulWidget {
  const ResetUserPasswordDialog({super.key, required this.member});

  final AppUser member;

  @override
  State<ResetUserPasswordDialog> createState() =>
      _ResetUserPasswordDialogState();
}

class _ResetUserPasswordDialogState extends State<ResetUserPasswordDialog> {
  final _senha = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (_senha.text.length < 6) {
      setState(() =>
          _erro = 'A senha temporária deve ter no mínimo 6 caracteres.');
      return;
    }
    Navigator.of(context).pop(_senha.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text('Redefinir senha',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Defina uma senha temporária para ${widget.member.name} '
              '(${widget.member.email}). No próximo acesso, o sistema pede '
              'para criar uma senha nova.',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthTextField(
              key: const Key('campo-senha-temporaria'),
              label: 'Senha temporária',
              hint: 'Mínimo de 6 caracteres',
              obscureText: true,
              controller: _senha,
            ),
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Text(_erro!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                key: const Key('confirmar-senha-temporaria'),
                onPressed: _confirmar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Redefinir senha',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
