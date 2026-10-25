import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'account_menu_button.dart';

/// Navbar superior usada só no layout web (largura >= AppShell.webBreakpoint).
/// Itens vêm de [navItems] (calculados pelo AppShell via
/// `NavItems.forRole(role)` — RN04: "Users" só aparece pra ADM), então
/// a navbar web nunca fica fora de sincronia com o BottomNavBar mobile.
class TopNavBar extends StatelessWidget {
  final int currentIndex;
  final List<({IconData icon, String label})> navItems;
  final ValueChanged<int> onNavTap;

  const TopNavBar({
    super.key,
    required this.currentIndex,
    required this.navItems,
    required this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: Color(0xFFEDEFF3))),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          const Text(
            'Tecsys',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(width: AppSpacing.xl),
          // Exclui o último item (Login/conta) — esse vira o
          // AccountMenuButton lá embaixo, nunca um link de aba.
          for (var i = 0; i < navItems.length - 1; i++) ...[
            _NavLink(
              label: navItems[i].label,
              active: i == currentIndex,
              onTap: () => onNavTap(i),
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
          const Spacer(),
          Text(
            AuthService.instance.name ?? AuthService.instance.email ?? '',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          const AccountMenuButton(),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavLink({required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 2, width: 20, color: active ? AppColors.primary : Colors.transparent),
        ],
      ),
    );
  }
}