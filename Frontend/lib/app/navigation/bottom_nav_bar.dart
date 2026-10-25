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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(navItems.length, (i) {
            final item = navItems[i];
            final active = i == currentIndex;
            final color = active ? AppColors.primary : AppColors.textSecondary;
            final label =
                item.label == 'ETL & Geodados' ? 'ETL\nGeodados' : item.label;

            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: SizedBox(
                  height: 52,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 26,
                        child: Icon(item.icon, size: 24, color: color),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 24,
                        child: Text(
                          label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.05,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
