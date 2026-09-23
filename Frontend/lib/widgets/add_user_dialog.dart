import 'package:flutter/material.dart';

import '../services/user_model.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_text_field.dart';

/// Resultado do formulário — já no formato que
/// [UserApiService.createUser] espera (role como [UserRoleType], não
/// String solta).
class AddUserResult {
  final String fullName;
  final String email;
  final String password;
  final UserRoleType role;

  const AddUserResult({
    required this.fullName,
    required this.email,
    required this.password,
    required this.role,
  });
}

/// Modal de "Add User" (US-34/RN01 — só ADM chega até aqui;
/// UsersScreen já bloqueia USER antes disso). Mesmo estilo visual dos
/// outros modais do app ([FirstAccessModal]): [Dialog] com largura
/// máxima e [AuthTextField] pros campos de texto. Mesmo widget serve
/// web e mobile.
Future<AddUserResult?> showAddUserDialog(BuildContext context) {
  return showDialog<AddUserResult>(
    context: context,
    builder: (_) => const _AddUserDialog(),
  );
}

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog();

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRoleType _role = UserRoleType.user;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty) {
      setState(() => _error = 'Nome e e-mail são obrigatórios.');
      return;
    }
    // Mesma regra do ChangePasswordDto (@Size min = 6) — validação
    // client-side só pra feedback imediato, o backend valida de novo.
    // O usuário troca essa senha no primeiro login (RN02).
    if (password.length < 6) {
      setState(() => _error = 'A senha inicial deve ter no mínimo 6 caracteres.');
      return;
    }

    Navigator.of(context).pop(AddUserResult(
      fullName: name,
      email: email,
      password: password,
      role: _role,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Novo usuário',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'O usuário é criado por você, a senha inicial precisa ser trocada no primeiro login.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              AuthTextField(
                label: 'Nome completo',
                hint: 'Ex.: Ana Silva',
                controller: _nameController,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'E-mail',
                hint: 'name@tecsys.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'Senha inicial',
                hint: '••••••••',
                obscureText: true,
                controller: _passwordController,
              ),
              const SizedBox(height: 16),
              const Text(
                'Perfil de acesso',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<UserRoleType>(
                    value: _role,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: UserRoleType.user, child: Text('USER')),
                      DropdownMenuItem(value: UserRoleType.adm, child: Text('ADM')),
                    ],
                    onChanged: (v) => setState(() => _role = v ?? _role),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Cadastrar', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}