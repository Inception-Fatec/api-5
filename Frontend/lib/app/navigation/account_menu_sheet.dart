import 'package:flutter/material.dart';

import 'package:tecsys_app/app/navigation/account_actions.dart';
import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/auth/data/services/auth_service.dart';

/// Menu de conta mobile: bottom sheet com o usuário logado e as ações
/// "Redefinir Senha" e "Sair". Mesmas ações do dropdown web
/// ([AccountMenuButton]) — muda só a apresentação.
Future<void> showAccountMenu(BuildContext context) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    builder: (sheetContext) => const _AccountSheet(),
  );

  if (selected == null || !context.mounted) return;

  if (selected == 'reset') {
    openResetPassword(context, fromLogin: false);
  } else if (selected == 'logout') {
    handleLogout(context);
  }
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final name = auth.name ?? auth.email ?? 'Minha conta';
    final subtitle = auth.name != null ? auth.email : null;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, color: AppColors.onPrimary),
            ),
            title: Text(name, style: AppTextStyles.sectionLabel),
            subtitle: subtitle == null
                ? null
                : Text(subtitle, style: AppTextStyles.caption),
          ),
          const Divider(height: AppSpacing.md),
          ListTile(
            leading: const Icon(Icons.lock_reset, color: AppColors.primary),
            title: const Text('Redefinir Senha'),
            onTap: () => Navigator.of(context).pop('reset'),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Sair'),
            onTap: () => Navigator.of(context).pop('logout'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
