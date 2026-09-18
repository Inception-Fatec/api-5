import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/reset_password_screen.dart';
import '../theme/app_theme.dart';

/// Bottom nav bar: Projects / New / Map / Login. Every tap is handed
/// to [onTap] — each screen decides what happens (navigate, show a
/// snackbar, open the account menu, etc).
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const items = [
    (icon: Icons.folder_outlined, label: 'Projects'),
    (icon: Icons.add_circle_outline, label: 'New'),
    (icon: Icons.location_on_outlined, label: 'Map'),
    (icon: Icons.lock_outline, label: 'Login'),
  ];

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
          children: List.generate(items.length, (i) {
            final item = items[i];
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

/// Shared "account" popup — Reset Password / Logout — used by screens
/// that want the Login tab to open a menu instead of navigating
/// straight away.
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
    );
  } else if (selected == 'logout') {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}
