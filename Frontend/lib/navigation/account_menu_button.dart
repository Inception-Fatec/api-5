import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'account_actions.dart';

/// Avatar de conta usado na [TopNavBar]. Ao clicar, abre um dropdown
/// com "Reset Password" e "Logout" — as mesmas duas ações do menu de
/// conta mobile (`showAccountMenu`, bottom sheet), só que como menu
/// suspenso ancorado no avatar. Diferença de apresentação (dropdown
/// vs. bottom sheet) por ser mais natural em cada plataforma; o
/// conteúdo e as ações disponíveis são idênticos nas duas.
class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE4E8EF)),
      ),
      onSelected: (value) {
        if (value == 'reset') {
          openResetPassword(context, fromLogin: false);
        } else if (value == 'logout') {
          handleLogout(context);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'reset',
          child: Row(
            children: [
              Icon(Icons.lock_reset, size: 18, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Reset Password'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: AppColors.textSecondary),
              SizedBox(width: 10),
              Text('Logout'),
            ],
          ),
        ),
      ],
      child: const CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.primary,
        child: Icon(Icons.person, size: 16, color: Colors.white),
      ),
    );
  }
}