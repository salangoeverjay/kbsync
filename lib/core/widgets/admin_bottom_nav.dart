import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';

enum AdminNavTab { home, wallet, profile }

class AdminBottomNav extends StatelessWidget {
  final AdminNavTab active;
  final ValueChanged<AdminNavTab> onTap;

  const AdminBottomNav({required this.active, required this.onTap, super.key});

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
              _AdminNavItem(
                icon: Icons.verified_user_rounded,
                label: 'Approvals',
                tab: AdminNavTab.home,
                active: active,
                onTap: onTap,
              ),
              _AdminNavItem(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Wallet',
                tab: AdminNavTab.wallet,
                active: active,
                onTap: onTap,
              ),
              _AdminNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                tab: AdminNavTab.profile,
                active: active,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final AdminNavTab tab;
  final AdminNavTab active;
  final ValueChanged<AdminNavTab> onTap;

  const _AdminNavItem({
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
          color: isActive
              ? AppColors.plum.withValues(alpha: 0.09)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? AppColors.plum : const Color(0xFFBEC8D1),
            ),
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
