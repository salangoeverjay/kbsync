import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/widgets/admin_bottom_nav.dart';
import 'package:kbsync/features/admin/presentation/screens/admin_transactions_screen.dart';
import 'package:kbsync/features/admin/presentation/screens/admin_wallet_screen.dart';
import 'package:kbsync/features/admin/presentation/screens/admin_profile_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminNavTab _activeTab = AdminNavTab.home;

  String _getTitle() {
    return switch (_activeTab) {
      AdminNavTab.home => 'Approvals',
      AdminNavTab.wallet => 'Platform Wallet',
      AdminNavTab.profile => 'Admin Profile',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _AdminHeader(title: _getTitle()),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      bottomNavigationBar: AdminBottomNav(
        active: _activeTab,
        onTap: (tab) {
          setState(() => _activeTab = tab);
        },
      ),
    );
  }

  Widget _buildContent() {
    return switch (_activeTab) {
      AdminNavTab.home => const AdminTransactionsScreenContent(),
      AdminNavTab.wallet => const AdminWalletScreenContent(),
      AdminNavTab.profile => const AdminProfileScreen(),
    };
  }
}

// Header Component
class _AdminHeader extends StatelessWidget {
  final String title;

  const _AdminHeader({required this.title});

  String _greetingForNow() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greetingForNow()} 👋',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.6,
                    color: AppColors.plum,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
