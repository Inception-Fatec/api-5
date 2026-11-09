import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Resultado do formulário de novo usuário.
class NewUserData {
  final String fullName;
  final String email;
  final String role; // 'USER' ou 'ADMIN'
  final String password;

  NewUserData({
    required this.fullName,
    required this.email,
    required this.role,
    required this.password,
  });
}

/// Abre o modal "Novo usuário" centralizado, como os outros modais do app.
/// Devolve o [NewUserData] preenchido, ou null se o usuário cancelar.
Future<NewUserData?> showAddUserDialog(BuildContext context) {
  return showDialog<NewUserData>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: const AddUserDialog(),
      ),
    ),
  );
}

class AddUserDialog extends StatefulWidget {
  const AddUserDialog({super.key});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _role = 'USER';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE4E8EF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE4E8EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _roleOption(String role) {
    final selected = _role == role;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _role = role),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.background : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: selected ? AppColors.success : AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                role == 'ADMIN' ? 'Administrador' : 'Usuário',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSave() {
    Navigator.of(context).pop(
      NewUserData(
        fullName: _nameController.text,
        email: _emailController.text,
        role: _role,
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Novo usuário',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      SizedBox(height: 2),
                      Text('Cadastre o acesso e o perfil do usuário',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _label('NOME COMPLETO'),
            TextField(
              controller: _nameController,
              style:
                  const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              decoration: _decoration('ex.: Maria Silva'),
            ),
            const SizedBox(height: AppSpacing.md),
            _label('E-MAIL'),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style:
                  const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              decoration: _decoration('nome@tecsys.com.br'),
            ),
            const SizedBox(height: AppSpacing.md),
            _label('PERFIL'),
            Row(
              children: [
                _roleOption('USER'),
                const SizedBox(width: AppSpacing.sm),
                _roleOption('ADMIN'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _label('SENHA'),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style:
                  const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              decoration: _decoration('••••••••').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Salvar',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
