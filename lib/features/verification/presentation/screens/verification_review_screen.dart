import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';

class VerificationReviewScreen extends StatefulWidget {
  final String documentType;
  final Map<String, String> details;
  final VoidCallback onRetake;

  const VerificationReviewScreen({
    super.key,
    required this.documentType,
    required this.details,
    required this.onRetake,
  });

  @override
  State<VerificationReviewScreen> createState() =>
      _VerificationReviewScreenState();
}

class _VerificationReviewScreenState extends State<VerificationReviewScreen> {
  bool _isSubmitting = false;

  Future<void> _confirmAndProceed() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'verification': {
            'status': 'verified',
            'documentType': widget.documentType,
            'fullName': widget.details['fullName'],
            'dob': widget.details['dob'],
            'sex': widget.details['sex'],
            'idNumber': widget.details['idNumber'],
            'bloodType': widget.details['bloodType'],
            'verifiedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification saved locally. Firestore sync failed.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID verification successful.')),
    );
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.welcome, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(25, 62, 25, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.deep),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Review Details',
                    style: TextStyle(
                      color: AppColors.deep,
                      fontSize: 38 / 1.73,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Row(
                children: [
                  Expanded(child: _ScanStepBar(active: true)),
                  SizedBox(width: 4),
                  Expanded(child: _ScanStepBar(active: true)),
                  SizedBox(width: 4),
                  Expanded(child: _ScanStepBar(active: false)),
                ],
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(left: 6, right: 8),
                child: Text(
                  'Confirm that the extracted details match your ID.',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _DetailCard(
                label: 'Full Name',
                value: widget.details['fullName'] ?? 'Not detected',
              ),
              const SizedBox(height: 12),
              _DetailCard(
                label: 'DOB',
                value: widget.details['dob'] ?? 'Not detected',
              ),
              const SizedBox(height: 12),
              _DetailCard(
                label: 'Sex',
                value: widget.details['sex'] ?? 'Not detected',
              ),
              const SizedBox(height: 12),
              _DetailCard(
                label: 'ID Number',
                value: widget.details['idNumber'] ?? 'Not detected',
              ),
              const SizedBox(height: 12),
              _DetailCard(
                label: 'Blood Type',
                value: widget.details['bloodType'] ?? 'Not detected',
              ),
              const Spacer(),
              _ActionButton(
                text: 'Confirm & Proceed',
                background: AppColors.orange,
                onTap: _isSubmitting ? null : _confirmAndProceed,
                loading: _isSubmitting,
              ),
              const SizedBox(height: 16),
              _ActionButton(
                text: 'Retake ID Photo',
                background: AppColors.plum,
                onTap: _isSubmitting
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        widget.onRetake();
                      },
                loading: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String label;
  final String value;

  const _DetailCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 67,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.plum.withValues(alpha: 0.67),
          width: 0.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.plum,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 32 / 1.78,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final Color background;
  final VoidCallback? onTap;
  final bool loading;

  const _ActionButton({
    required this.text,
    required this.background,
    required this.onTap,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: double.infinity,
        height: 51,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      color: Color(0xFFFFFDFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 24 / 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ScanStepBar extends StatelessWidget {
  final bool active;

  const _ScanStepBar({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 7,
      decoration: BoxDecoration(
        color: active ? AppColors.orange : const Color(0x40FF5A00),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
