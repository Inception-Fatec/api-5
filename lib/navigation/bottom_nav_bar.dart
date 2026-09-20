import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'account_actions.dart';
import 'nav_items.dart';

/// Bottom nav bar mobile: mesmas 4 abas de [NavItems.all]. Cada tap é
/// repassado pra [onTap] — quem decide o que fazer é o AppShell.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: Color(0xFFEDEFF3))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(NavItems.all.length, (i) {
            final item = NavItems.all[i];
            final active = i == currentIndex;
            final color = active ? AppColors.primary : AppColors.textSecondary;

            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 24, color: color),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Menu de conta mobile — bottom sheet com "Reset Password" e
/// "Logout". Mesma lógica de [AccountMenuButton] (dropdown web),
/// só que como bottom sheet: diferença de apresentação, não de
/// conteúdo ou de ações disponíveis.
Future<void> showAccountMenu(BuildContext context) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.lock_reset, color: AppColors.primary),
              title: const Text('Reset Password'),
              onTap: () => Navigator.of(sheetContext).pop('reset'),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.textSecondary),
              title: const Text('Logout'),
              onTap: () => Navigator.of(sheetContext).pop('logout'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );

  if (selected == null || !context.mounted) return;

  if (selected == 'reset') {
    openResetPassword(context, fromLogin: false);
  } else if (selected == 'logout') {
    handleLogout(context);
  }
}