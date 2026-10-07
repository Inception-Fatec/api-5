import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';

/// Bottom nav bar mobile: itens vêm de [navItems] (calculados pelo
/// AppShell via `NavItems.forRole(role)` — RN04: "Users" só aparece
/// pra ADM). Cada tap é repassado pra [onTap] — quem decide o que
/// fazer é o AppShell.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final List<({IconData icon, String label})> navItems;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.navItems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(navItems.length, (i) {
            final item = navItems[i];
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
