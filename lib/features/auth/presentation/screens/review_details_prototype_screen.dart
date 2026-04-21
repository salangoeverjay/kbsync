import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/auth/presentation/screens/face_match_result_screen.dart';
import 'package:kbsync/features/auth/presentation/screens/verification_complete_screen.dart';

class ReviewDetailsPrototypeScreen extends StatelessWidget {
  final String documentLabel;
  final String referenceImagePath;
  final String? requestId;
  final String? status;
  final String? fullName;
  final String? dateOfBirth;
  final String? sex;
  final String? idNumber;

  const ReviewDetailsPrototypeScreen({
    super.key,
    required this.documentLabel,
    required this.referenceImagePath,
    this.requestId,
    this.status,
    this.fullName,
    this.dateOfBirth,
    this.sex,
    this.idNumber,
  });

  String get _numberFieldLabel =>
      documentLabel.toLowerCase().contains('driver')
          ? 'License Number'
          : 'ID Number';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 18, bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 55, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.deep,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Review Details',
                    style: TextStyle(
                      color: AppColors.deep,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 1),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: _ProgressBar(),
            ),
            const SizedBox(height: 5),
            const Padding(
              padding: EdgeInsets.fromLTRB(35, 0, 38, 0),
              child: Text(
                'Confirm that the extracted details match your ID.',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 17),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  _DetailCard(label: 'Full Name', value: fullName ?? 'Not available'),
                  const SizedBox(height: 12),
                  _DetailCard(label: 'DOB', value: dateOfBirth ?? 'Not available'),
                  const SizedBox(height: 12),
                  _DetailCard(label: 'Sex', value: sex ?? 'Not available'),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _DetailCard(
                label: _numberFieldLabel,
                value: idNumber ?? 'Not available',
              ),
            ),
            if (requestId != null || status != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
                child: Text(
                  'Request: ${requestId ?? '-'} | Status: ${status ?? '-'}',
                  style: TextStyle(
                    color: AppColors.ink.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 78),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: _ActionButton(
                text: 'Confirm & Proceed',
                color: AppColors.orange,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VerificationCompleteScreen(
                      requiresPassiveLiveness: true,
                      detectedLabel: 'Verify Liveness',
                      onPassiveLivenessApproved: (selfiePath) {
                        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown-user';
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => FaceMatchResultScreen(
                              userId: userId,
                              userImagePath: selfiePath,
                              referenceImagePath: referenceImagePath,
                            ),
                          ),
                        );
                      },
                      ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: _ActionButton(
                text: 'Retake ID Photo',
                color: AppColors.plum,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: const [
          _Segment(color: AppColors.orange),
          SizedBox(width: 3),
          _Segment(color: AppColors.orange),
          SizedBox(width: 3),
          _Segment(color: Color(0x40FF5A00)),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final Color color;

  const _Segment({required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Align(
        alignment: Alignment.center,
        child: Container(
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String label;
  final String value;

  const _DetailCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24.5, vertical: 12),
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
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: double.infinity,
        height: 51,
        decoration: BoxDecoration(
          color: color,
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
            child: Text(
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
