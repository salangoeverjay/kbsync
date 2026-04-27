import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';

enum KbNavTab { home, tasks, wallet, profile }

class KbBottomNav extends StatelessWidget {
  final KbNavTab active;
  final ValueChanged<KbNavTab> onTap;

  const KbBottomNav({required this.active, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: AppColors.plum.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Home', tab: KbNavTab.home, active: active, onTap: onTap),
              _NavItem(icon: Icons.grid_view_rounded, label: 'Tasks', tab: KbNavTab.tasks, active: active, onTap: onTap),
              _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Wallet', tab: KbNavTab.wallet, active: active, onTap: onTap),
              _NavItem(icon: Icons.person_rounded, label: 'Profile', tab: KbNavTab.profile, active: active, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final KbNavTab tab;
  final KbNavTab active;
  final ValueChanged<KbNavTab> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.tab,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = tab == active;
    return GestureDetector(
      onTap: () => onTap(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.plum.withValues(alpha: 0.09) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: isActive ? AppColors.plum : const Color(0xFFBEC8D1)),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isActive ? AppColors.plum : const Color(0xFFBEC8D1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
