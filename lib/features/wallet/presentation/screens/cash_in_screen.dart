import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/widgets/kb_buttons.dart';
import 'package:kbsync/features/wallet/data/wallet_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CashInScreen extends StatefulWidget {
  const CashInScreen({super.key});

  @override
  State<CashInScreen> createState() => _CashInScreenState();
}

class _CashInScreenState extends State<CashInScreen> {
  final TextEditingController _amountController = TextEditingController();
  final WalletService _walletService = WalletService();
  static const _quickAmounts = [100, 200, 500, 1000, 2000, 5000];
  static const _sourceFee = 0;

  bool _waitingForRedirect = false;

  static const _sources = [
    (
      id: 'gcash',
      name: 'GCash',
      icon: Icons.account_balance_wallet_rounded,
      subtitle: 'Linked • +63 9XX • • • 4521',
      bg: Color(0xFFEFF6FF),
      iconColor: Color(0xFF2563EB),
    ),
    (
      id: 'maya',
      name: 'Maya',
      icon: Icons.payments_rounded,
      subtitle: 'Tap to link account',
      bg: Color(0xFFF3F0FF),
      iconColor: Color(0xFF6D28D9),
    ),
    (
      id: 'bank',
      name: 'Bank Transfer',
      icon: Icons.account_balance_rounded,
      subtitle: 'BPI, BDO, UnionBank, +6 more',
      bg: Color(0xFFECFDF5),
      iconColor: Color(0xFF047857),
    ),
    (
      id: 'over_the_counter',
      name: 'Over-the-Counter',
      icon: Icons.storefront_rounded,
      subtitle: '7-Eleven, Cebuana, M Lhuillier',
      bg: Color(0xFFFFF7ED),
      iconColor: AppColors.orange,
    ),
  ];

  String _selectedSource = 'gcash';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _amount {
    final raw = _amountController.text.replaceAll(',', '').trim();
    return int.tryParse(raw) ?? 0;
  }

  int get _total => _amount + _sourceFee;

  String _formatPeso(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '₱$buf';
  }

  void _setQuickAmount(int v) {
    setState(() {
      _amountController.text = v.toString();
      _amountController.selection = TextSelection.fromPosition(
        TextPosition(offset: _amountController.text.length),
      );
    });
  }

  bool get _canContinue => _amount >= 50;

  void _onContinue() {
    if (!_canContinue) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        amount: _formatPeso(_amount),
        total: _formatPeso(_total),
        sourceName: _sources.firstWhere((s) => s.id == _selectedSource).name,
        onConfirm: () {
          Navigator.of(context).pop();
          _submitCashIn();
        },
      ),
    );
  }

  Future<void> _submitCashIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again to continue cash in.'),
        ),
      );
      return;
    }

    final sourceName = _sources.firstWhere((s) => s.id == _selectedSource).name;

    setState(() => _waitingForRedirect = true);
    try {
      // Determine the app URL based on selected source
      late String appUrl;
      late String appName;

      switch (_selectedSource) {
        case 'gcash':
          appUrl = 'https://www.gcash.com/';
          appName = 'GCash';
          break;
        case 'maya':
          appUrl = 'https://www.mayaapp.com/';
          appName = 'Maya';
          break;
        case 'bank':
          appName = 'Bank Transfer';
          // Show instructions instead
          if (!mounted) return;
          _showBankTransferInstructions();
          return;
        case 'over_the_counter':
          appName = 'Over-the-Counter';
          // Show OTC instructions instead
          if (!mounted) return;
          _showOtcInstructions();
          return;
        default:
          throw StateError('Unknown payment source: $_selectedSource');
      }

      // Record the pending cash-in transaction
      await _walletService.recordCashIn(
        uid: uid,
        amount: _amount.toDouble(),
        sourceName: sourceName,
      );

      // Open the payment app
      final launched = await launchUrl(
        Uri.parse(appUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw StateError('Could not open $appName.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening $appName to complete ₱$_amount cash-in...'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.plum,
        ),
      );
      Navigator.of(context).pop();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cash in failed: $err')));
    } finally {
      if (mounted) {
        setState(() => _waitingForRedirect = false);
      }
    }
  }

  void _showBankTransferInstructions() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bank Transfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send ₱$_amount to:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bank: BPI / BDO / UnionBank',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Account: Ka-Bayan Sync',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Amount: ₱$_amount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your wallet will be credited within 1-2 hours.',
              style: TextStyle(fontSize: 11, color: AppColors.ink),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showOtcInstructions() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Over-the-Counter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visit any of these outlets:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• 7-Eleven', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  const Text(
                    '• Cebuana Lhuillier',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  const Text('• M Lhuillier', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Reference: Ka-Bayan Sync | Amount: ₱$_amount',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your wallet will be credited within 2-4 hours.',
              style: TextStyle(fontSize: 11, color: AppColors.ink),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total to Cash In',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    _formatPeso(_total),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.plum,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              KbGradientButton(
                text: _waitingForRedirect ? 'Opening app…' : 'Continue',
                onTap: (_canContinue && !_waitingForRedirect)
                    ? _onContinue
                    : null,
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.plum,
            child: SafeArea(
              bottom: false,
              child: _Header(onBack: () => Navigator.of(context).pop()),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How much would you like to add?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.6,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Minimum cash in is ₱50.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.ink.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AmountInput(
                    controller: _amountController,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _QuickAmountChips(
                    amounts: _quickAmounts,
                    onSelect: _setQuickAmount,
                    formatPeso: _formatPeso,
                  ),
                  const SizedBox(height: 26),
                  const _SectionLabel('CASH IN VIA'),
                  const SizedBox(height: 10),
                  ..._sources.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SourceTile(
                        name: s.name,
                        subtitle: s.subtitle,
                        icon: s.icon,
                        bg: s.bg,
                        iconColor: s.iconColor,
                        selected: _selectedSource == s.id,
                        onTap: () => setState(() => _selectedSource = s.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SecurityFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
              'Cash In',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.greenLt.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, size: 12, color: AppColors.green),
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
        ],
      ),
    );
  }
}

class _AmountInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _AmountInput({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: AppColors.grad,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33911B44),
            blurRadius: 24,
            offset: Offset(0, 8),
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
                  Icons.add_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Amount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '₱',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(7),
                  ],
                  cursorColor: Colors.white,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1.2,
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withValues(alpha: 0.45),
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'No transaction fees',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAmountChips extends StatelessWidget {
  final List<int> amounts;
  final ValueChanged<int> onSelect;
  final String Function(int) formatPeso;

  const _QuickAmountChips({
    required this.amounts,
    required this.onSelect,
    required this.formatPeso,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: amounts
          .map(
            (a) => GestureDetector(
              onTap: () => onSelect(a),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.plum.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  formatPeso(a),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.plum,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: AppColors.ink.withValues(alpha: 0.5),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color bg;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  const _SourceTile({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.bg,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.orange
                : AppColors.plum.withValues(alpha: 0.1),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.ink.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.orange
                      : Colors.black.withValues(alpha: 0.15),
                  width: 2,
                ),
                color: selected ? AppColors.orange : Colors.transparent,
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.plum.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.plum.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_rounded,
              size: 16,
              color: AppColors.plum,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Funds are held in escrow until released. You won\'t be charged any fees today.',
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: AppColors.ink.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  final String amount;
  final String total;
  final String sourceName;
  final VoidCallback onConfirm;

  const _ConfirmSheet({
    required this.amount,
    required this.total,
    required this.sourceName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const Text(
              'Confirm Cash In',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Review your cash in details before continuing.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.ink.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 18),
            _row('Amount', amount),
            const SizedBox(height: 10),
            _row('Source', sourceName),
            const SizedBox(height: 10),
            _row('Fee', '₱0'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Container(
                height: 1,
                color: AppColors.ink.withValues(alpha: 0.08),
              ),
            ),
            _row('Total', total, emphasize: true),
            const SizedBox(height: 18),
            KbGradientButton(text: 'Confirm', onTap: onConfirm),
            const SizedBox(height: 8),
            KbGhostButton(
              text: 'Cancel',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.ink.withValues(alpha: emphasize ? 0.85 : 0.6),
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 18 : 14,
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
            color: emphasize ? AppColors.plum : AppColors.ink,
            letterSpacing: emphasize ? -0.4 : 0,
          ),
        ),
      ],
    );
  }
}
