import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/admin/data/admin_service.dart';

// Content-only version for use in dashboard
class AdminWalletScreenContent extends StatefulWidget {
  const AdminWalletScreenContent({super.key});

  @override
  State<AdminWalletScreenContent> createState() =>
      _AdminWalletScreenContentState();
}

class _AdminWalletScreenContentState extends State<AdminWalletScreenContent> {
  final AdminService _service = AdminService();

  String _formatCurrencyFromCentavos(int value) {
    final amount = value / 100;
    final fixed = amount.toStringAsFixed(2);
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

  Future<void> _openWithdrawSheet(int balanceCentavos) async {
    final amountController = TextEditingController();
    final accountNameController = TextEditingController();
    final accountNumberController = TextEditingController();
    String method = 'bank';
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            Future<void> submit() async {
              final amountText = amountController.text.trim();
              final accountName = accountNameController.text.trim();
              final accountNumber = accountNumberController.text.trim();

              final amountPeso = double.tryParse(amountText);
              if (amountPeso == null || amountPeso <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount.')),
                );
                return;
              }
              if (accountName.isEmpty || accountNumber.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fill in account details.')),
                );
                return;
              }

              final amountCentavos = (amountPeso * 100).round();
              if (amountCentavos > balanceCentavos) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Insufficient platform balance.'),
                  ),
                );
                return;
              }

              setLocalState(() => isSubmitting = true);
              try {
                await _service.withdrawPlatformFunds(
                  amount: amountCentavos,
                  method: method,
                  accountName: accountName,
                  accountNumber: accountNumber,
                );
                if (!mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Withdrawal request submitted.'),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Withdrawal failed: $e')),
                );
              } finally {
                if (ctx.mounted) {
                  setLocalState(() => isSubmitting = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Send to Bank',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Withdraw service fees from platform wallet.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.ink.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: method,
                    items: const [
                      DropdownMenuItem(value: 'bank', child: Text('Bank')),
                      DropdownMenuItem(value: 'gcash', child: Text('GCash')),
                      DropdownMenuItem(value: 'maya', child: Text('Maya')),
                    ],
                    onChanged: (v) => setLocalState(() => method = v ?? 'bank'),
                    decoration: const InputDecoration(labelText: 'Method'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (PHP)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: accountNameController,
                    decoration: const InputDecoration(
                      labelText: 'Account Name',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: accountNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Account Number',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSubmitting ? null : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.plum,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: const Text('Send / Withdraw'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _actorType(Map<String, dynamic> data) {
    final userId = (data['userId'] ?? '').toString();
    final meta = (data['meta'] ?? '').toString().toLowerCase();
    if (userId == 'platform') return 'Platform';
    if (meta.contains('from resident')) return 'Worker';
    if (meta.contains('task payment to')) return 'Resident';
    return 'User';
  }

  Color _actorColor(String actorType) {
    if (actorType == 'Resident') return AppColors.plum;
    if (actorType == 'Worker') return AppColors.orange;
    return AppColors.green;
  }

  String _formatWhen(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final now = DateTime.now();
    final isToday =
        now.year == dateTime.year &&
        now.month == dateTime.month &&
        now.day == dateTime.day;
    if (isToday) {
      final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return 'Today, $hour:$minute $period';
    }
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _service.platformAccountStream(),
      builder: (context, accountSnapshot) {
        if (accountSnapshot.hasError) {
          return Center(child: Text('Error: ${accountSnapshot.error}'));
        }
        if (!accountSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final doc = accountSnapshot.data!;
        final raw = doc.data();
        final data = raw is Map<String, dynamic>
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        final balanceCentavos = (data['balance'] as num?)?.toInt() ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: _service.transactionsStream(),
          builder: (context, txSnapshot) {
            final txDocs =
                txSnapshot.data?.docs ?? const <QueryDocumentSnapshot>[];
            final residentWorkerTx = txDocs
                .where((doc) {
                  final rawTx = doc.data();
                  final tx = rawTx is Map<String, dynamic>
                      ? Map<String, dynamic>.from(rawTx)
                      : <String, dynamic>{};
                  final userId = (tx['userId'] ?? '').toString();
                  return userId.isNotEmpty && userId != 'platform';
                })
                .take(20)
                .toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppColors.grad,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33911B44),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Service Fee Wallet',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatCurrencyFromCentavos(balanceCentavos),
                          style: const TextStyle(
                            fontSize: 31,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Auto +10% per approved task',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _openWithdrawSheet(balanceCentavos),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.plum,
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: const Text('Send'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Recent Resident / Worker Transactions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (residentWorkerTx.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'No recent resident or worker transactions.',
                      ),
                    )
                  else
                    ...residentWorkerTx.map((doc) {
                      final rawTx = doc.data();
                      final tx = rawTx is Map<String, dynamic>
                          ? Map<String, dynamic>.from(rawTx)
                          : <String, dynamic>{};
                      final amount = (tx['amount'] as num?)?.toInt() ?? 0;
                      final type = (tx['type'] ?? '').toString().toLowerCase();
                      final actorType = _actorType(tx);
                      final actorColor = _actorColor(actorType);
                      final created = (tx['createdAt'] as Timestamp?)?.toDate();
                      final userName =
                          (tx['userName'] ?? tx['userId'] ?? 'unknown')
                              .toString();
                      final meta = (tx['meta'] ?? '').toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: actorColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                actorType == 'Worker'
                                    ? Icons.engineering_rounded
                                    : Icons.person_rounded,
                                color: actorColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$actorType • $meta',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.ink.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${type == 'credit' ? '+' : '-'}${_formatCurrencyFromCentavos(amount)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: type == 'credit'
                                        ? AppColors.green
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatWhen(created),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.ink.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class AdminWalletScreen extends StatelessWidget {
  const AdminWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin — Platform Wallet')),
      body: const AdminWalletScreenContent(),
    );
  }
}
