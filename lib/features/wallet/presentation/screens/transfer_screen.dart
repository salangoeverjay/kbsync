import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/wallet/data/paymongo_service.dart';
import 'package:kbsync/features/wallet/data/wallet_service.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final PaymongoService _paymongoService = PaymongoService();
  final WalletService _walletService = WalletService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  String _method = 'gcash'; // 'gcash', 'maya', 'bank'
  bool _isProcessing = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _processTransfer() async {
    final uid = _uid;
    if (uid == null) {
      _showError('User not authenticated');
      return;
    }

    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }

    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      _showError('Enter recipient details');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      // Validate balance first
      final walletTxns = await _walletService.watchTransactions(uid).first;
      double balance = 0;
      for (final tx in walletTxns) {
        balance += tx.isCredit ? tx.amount : -tx.amount;
      }

      if (balance < amount) {
        _showError('Insufficient balance');
        return;
      }

      // Create payout via PayMongo
      final payoutData = {
        'amountPesos': amount,
        'currency': 'PHP',
        'method': _method,
        'recipient': recipient,
        'description': 'KBSync Wallet Transfer to $_method',
      };

      // Call PayMongo payout API (via Cloud Function)
      await _paymongoService.createPayout(payoutData);

      if (!mounted) return;

      _showSuccess('Transfer sent successfully!');
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.wallet);
        }
      });
    } catch (error) {
      _showError('Transfer failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.plum),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.plum,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
        title: const Text(
          'Send Money',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Method Selection
            const Text(
              'Send via',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MethodButton(
                  label: 'GCash',
                  isSelected: _method == 'gcash',
                  onTap: () => setState(() => _method = 'gcash'),
                ),
                const SizedBox(width: 12),
                _MethodButton(
                  label: 'Maya',
                  isSelected: _method == 'maya',
                  onTap: () => setState(() => _method = 'maya'),
                ),
                const SizedBox(width: 12),
                _MethodButton(
                  label: 'Bank',
                  isSelected: _method == 'bank',
                  onTap: () => setState(() => _method = 'bank'),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Amount Input
            const Text(
              'Amount',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration.collapsed(
                  hintText: 'Enter amount (₱)',
                  hintStyle: TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 13,
                    color: AppColors.plum.withValues(alpha: 0.3),
                  ),
                ),
                style: const TextStyle(fontSize: 16, color: AppColors.plum),
              ),
            ),
            const SizedBox(height: 20),

            // Recipient Input
            Text(
              _method == 'bank' ? 'Bank Account Number' : 'Phone Number',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _recipientController,
                keyboardType: _method == 'bank'
                    ? TextInputType.text
                    : TextInputType.phone,
                decoration: InputDecoration.collapsed(
                  hintText: _method == 'bank'
                      ? 'Enter account number'
                      : 'Enter phone number',
                  hintStyle: TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 13,
                    color: AppColors.plum.withValues(alpha: 0.3),
                  ),
                ),
                style: const TextStyle(fontSize: 16, color: AppColors.plum),
              ),
            ),
            const SizedBox(height: 28),

            // Send Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.plum,
                  disabledBackgroundColor: AppColors.plum.withValues(
                    alpha: 0.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Send Money',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.plum : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.plum : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isSelected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
