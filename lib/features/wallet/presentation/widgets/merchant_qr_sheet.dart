import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/widgets/kb_buttons.dart';

class MerchantQrSheet extends StatefulWidget {
  final String formattedAmount;
  final String taskTitle;
  final String? qrCodeUrl;
  final Stream<DocumentSnapshot<Map<String, dynamic>>> taskStream;
  final VoidCallback onClose;
  final VoidCallback onFunded;

  const MerchantQrSheet({
    required this.formattedAmount,
    required this.taskTitle,
    required this.qrCodeUrl,
    required this.taskStream,
    required this.onClose,
    required this.onFunded,
    super.key,
  });

  @override
  State<MerchantQrSheet> createState() => _MerchantQrSheetState();
}

class _MerchantQrSheetState extends State<MerchantQrSheet> {
  bool _funded = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.taskStream,
      builder: (context, snap) {
        final escrow =
            snap.data?.data()?['escrow'] as Map<String, dynamic>?;
        final status = escrow?['status'] as String?;
        if (!_funded && status == 'funded') {
          _funded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onFunded();
          });
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                        'Pay at Merchant',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.taskTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.ink.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _AmountPill(amount: widget.formattedAmount),
                      const SizedBox(height: 18),
                      _QrPanel(qrCodeUrl: widget.qrCodeUrl),
                      const SizedBox(height: 18),
                      _StatusRow(status: status),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.plum.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: AppColors.plum,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Scan with any QR Ph–compatible app (GCash, Maya, BPI, BDO). Funds are held in escrow and released to the worker once the task is completed.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.45,
                                  color: AppColors.ink
                                      .withValues(alpha: 0.65),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      KbGhostButton(
                        text: 'Pay later',
                        onTap: widget.onClose,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AmountPill extends StatelessWidget {
  final String amount;
  const _AmountPill({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppColors.grad,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33911B44),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        amount,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class _QrPanel extends StatelessWidget {
  final String? qrCodeUrl;
  const _QrPanel({required this.qrCodeUrl});

  @override
  Widget build(BuildContext context) {
    final url = qrCodeUrl;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.plum.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: url == null || url.isEmpty
            ? const Center(
                child: Text(
                  'QR code unavailable.\nPlease retry from the task list.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mid,
                  ),
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.orange,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, _, _) => const Center(
                  child: Text(
                    'Could not load QR image.',
                    style: TextStyle(fontSize: 12, color: AppColors.mid),
                  ),
                ),
              ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String? status;
  const _StatusRow({required this.status});

  @override
  Widget build(BuildContext context) {
    final isFunded = status == 'funded';
    final isFailed = status == 'failed';
    final color = isFunded
        ? AppColors.green
        : isFailed
            ? const Color(0xFFDC2626)
            : AppColors.orange;
    final label = isFunded
        ? 'Payment received'
        : isFailed
            ? 'Payment failed'
            : 'Waiting for payment';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!isFunded && !isFailed)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          )
        else
          Icon(
            isFunded ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 16,
            color: color,
          ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
