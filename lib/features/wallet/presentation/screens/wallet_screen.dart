import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/widgets/kb_bottom_nav.dart';
import 'package:kbsync/features/auth/data/firebase_auth_service.dart';
import 'package:kbsync/features/wallet/data/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final WalletService _walletService = WalletService();
  String? _userRole;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final verificationState = await _authService.getVerificationState(
        uid: userId,
      );
      if (mounted) {
        setState(() {
          _userRole = verificationState?.role;
        });
      }
    } catch (_) {}
  }

  Future<String> _resolveUserRole() async {
    final cached = _userRole;
    if (cached != null && cached.isNotEmpty) return cached;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return 'resident';

    try {
      final verificationState = await _authService.getVerificationState(
        uid: userId,
      );
      final role = verificationState?.role?.trim().toLowerCase();
      if (role != null && role.isNotEmpty) {
        if (mounted) {
          setState(() {
            _userRole = role;
          });
        }
        return role;
      }
    } catch (_) {}

    return 'resident';
  }

  Future<void> _onNavTap(KbNavTab tab) async {
    if (tab == KbNavTab.wallet) return;

    final role = await _resolveUserRole();
    if (!mounted) return;

    if (tab == KbNavTab.home) {
      final homeRoute = role == 'resident'
          ? AppRoutes.residentDashboard
          : AppRoutes.workerDashboard;
      Navigator.of(context).pushReplacementNamed(homeRoute);
    } else if (tab == KbNavTab.tasks) {
      final tasksRoute = role == 'resident'
          ? AppRoutes.createTask
          : AppRoutes.nearbyTasks;
      Navigator.of(context).pushReplacementNamed(tasksRoute);
    } else if (tab == KbNavTab.profile) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.profile);
    }
  }

  String _formatCurrency(double value) {
    final abs = value.abs();
    final fixed = abs.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first;
    final decimal = parts.last;

    final out = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i != 0 && (whole.length - i) % 3 == 0) {
        out.write(',');
      }
      out.write(whole[i]);
    }
    return '₱${out.toString()}.$decimal';
  }

  String _formatSignedAmount(double value, bool isCredit) {
    final sign = isCredit ? '+' : '-';
    return '$sign${_formatCurrency(value)}';
  }

  String _formatDateTimeLabel(DateTime date) {
    final now = DateTime.now();
    final isToday =
        now.year == date.year && now.month == date.month && now.day == date.day;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    if (isToday) return 'Today, $hour:$minute $period';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  double _monthlySpent(List<WalletTransaction> txns) {
    final now = DateTime.now();
    return txns
        .where(
          (t) =>
              !t.isCredit &&
              t.createdAt.year == now.year &&
              t.createdAt.month == now.month,
        )
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  IconData _transactionIcon(WalletTransaction t) {
    if (t.category == 'cash_in') return Icons.add_rounded;
    if (t.category == 'pabili' || t.title.toLowerCase().contains('grocery')) {
      return Icons.shopping_cart_rounded;
    }
    if (t.title.toLowerCase().contains('laundry')) {
      return Icons.local_laundry_service_rounded;
    }
    if (t.title.toLowerCase().contains('dish')) return Icons.restaurant_rounded;
    return Icons.cleaning_services_rounded;
  }

  String _transactionEmoji(WalletTransaction t) {
    if (t.category == 'cash_in') return '💳';
    if (t.category == 'pabili' || t.title.toLowerCase().contains('grocery')) {
      return '🛒';
    }
    if (t.title.toLowerCase().contains('laundry')) return '🧺';
    if (t.title.toLowerCase().contains('dish')) return '🍽️';
    return '🧹';
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        bottomNavigationBar: KbBottomNav(
          active: KbNavTab.wallet,
          onTap: (tab) => _onNavTap(tab),
        ),
        body: const Center(
          child: Text(
            'Please sign in to access wallet.',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.mid),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: KbBottomNav(
        active: KbNavTab.wallet,
        onTap: (tab) => _onNavTap(tab),
      ),
      body: StreamBuilder<WalletAccountData>(
        stream: _walletService.watchAccount(uid),
        builder: (context, accountSnapshot) {
          final account = accountSnapshot.data ?? WalletAccountData.empty;
          return StreamBuilder<List<WalletTransaction>>(
            stream: _walletService.watchTransactions(uid),
            builder: (context, txSnapshot) {
              final txns = txSnapshot.data ?? const <WalletTransaction>[];
              final monthlySpent = _monthlySpent(txns);
              return Column(
                children: [
                  _WalletHeader(onBack: () => Navigator.of(context).pop()),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BalanceSection(
                            balanceLabel: _formatCurrency(account.balance),
                            trustBondLabel: _formatCurrency(account.trustBond),
                            monthlyLabel: _formatCurrency(monthlySpent),
                          ),
                          const SizedBox(height: 20),
                          const _QuickActions(),
                          const SizedBox(height: 24),
                          _TransactionHistory(
                            transactions: txns,
                            formatSignedAmount: _formatSignedAmount,
                            formatDateTime: _formatDateTimeLabel,
                            resolveIcon: _transactionIcon,
                            resolveEmoji: _transactionEmoji,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _WalletHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _WalletHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.plum,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 20),
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Ka-Bayan Wallet',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.greenLt.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      size: 12,
                      color: AppColors.green,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'SECURED',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 1,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceSection extends StatelessWidget {
  final String balanceLabel;
  final String trustBondLabel;
  final String monthlyLabel;

  const _BalanceSection({
    required this.balanceLabel,
    required this.trustBondLabel,
    required this.monthlyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.grad,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33911B44),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Balance',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  balanceLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Available to spend',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: Column(
            children: [
              _MiniCard(
                label: 'Trust Bond',
                value: trustBondLabel,
                icon: Icons.verified_rounded,
                bg: AppColors.orangeLt,
                labelColor: AppColors.orange,
                valueColor: AppColors.orange,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color bg;
  final Color labelColor;
  final Color valueColor;

  const _MiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.bg,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: labelColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: valueColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    const actions = [
      (Icons.add_rounded, 'Cash In', AppColors.orange),
      (Icons.send_rounded, 'Send', AppColors.plum),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: actions.asMap().entries.map((entry) {
        final a = entry.value;
        return Padding(
          padding: EdgeInsets.only(left: entry.key == 0 ? 0 : 18),
          child: GestureDetector(
            onTap: () {
              if (a.$2 == 'Cash In') {
                Navigator.of(context).pushNamed(AppRoutes.walletCashIn);
              } else if (a.$2 == 'Send') {
                Navigator.of(context).pushNamed(AppRoutes.walletTransfer);
              }
            },
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: a.$3 == AppColors.orange
                        ? AppColors.orange
                        : AppColors.plum.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    a.$1,
                    size: 28,
                    color: a.$3 == AppColors.orange
                        ? Colors.white
                        : AppColors.plum,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  a.$2,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TransactionHistory extends StatefulWidget {
  final List<WalletTransaction> transactions;
  final String Function(double value, bool isCredit) formatSignedAmount;
  final String Function(DateTime value) formatDateTime;
  final IconData Function(WalletTransaction tx) resolveIcon;
  final String Function(WalletTransaction tx) resolveEmoji;

  const _TransactionHistory({
    required this.transactions,
    required this.formatSignedAmount,
    required this.formatDateTime,
    required this.resolveIcon,
    required this.resolveEmoji,
  });

  @override
  State<_TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<_TransactionHistory> {
  static const int _collapsedCount = 5;
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleTransactions = _expanded
        ? widget.transactions
        : widget.transactions.take(_collapsedCount).toList();
    final canToggle = widget.transactions.length > _collapsedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
            ),
            TextButton(
              onPressed: canToggle ? _toggleExpanded : null,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _expanded ? 'Show less' : 'View all',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: canToggle ? AppColors.orange : AppColors.mid,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: visibleTransactions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: Center(
                      child: Text(
                        'No transactions yet',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mid,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: visibleTransactions.asMap().entries.map((e) {
                      final i = e.key;
                      final t = e.value;
                      final isCredit = t.isCredit;
                      return Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        decoration: BoxDecoration(
                          border: i < visibleTransactions.length - 1
                              ? Border(
                                  bottom: BorderSide(color: AppColors.border),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isCredit
                                    ? AppColors.green.withValues(alpha: 0.1)
                                    : AppColors.orangeLt,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Center(
                                child: Text(
                                  widget.resolveEmoji(t),
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t.subtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.ink.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  widget.formatSignedAmount(t.amount, isCredit),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: isCredit
                                        ? AppColors.green
                                        : AppColors.ink,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.formatDateTime(t.createdAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.ink.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }
}
