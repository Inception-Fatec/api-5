import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'account_menu_button.dart';
import 'nav_items.dart';

/// Navbar superior usada só no layout web (largura >= AppShell.webBreakpoint).
/// Espelha o mesmo conjunto de abas do BottomNavBar mobile, lido de
/// [NavItems.all], então as duas navbars nunca ficam fora de sincronia.
class TopNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;

  const TopNavBar({super.key, required this.currentIndex, required this.onNavTap});

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
          for (var i = 0; i < NavItems.all.length - 1; i++) ...[
            _NavLink(
              label: NavItems.all[i].label,
              active: i == currentIndex,
              onTap: () => onNavTap(i),
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
          const Spacer(),
          Row(
            children: const [
              _SessionDot(),
              SizedBox(width: 6),
              Text('Active Session', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          const AccountMenuButton(),
        ],
      ),
    );
  }
}

class _SessionDot extends StatelessWidget {
  const _SessionDot();

  @override
  Widget build(BuildContext context) {
    return Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle));
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