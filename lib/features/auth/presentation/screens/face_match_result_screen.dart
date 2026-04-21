import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/auth/data/verification_api_service.dart';

enum _MatchStage { verifying, success, failed }

class FaceMatchResultScreen extends StatefulWidget {
  final String userId;
  final String userImagePath;
  final String referenceImagePath;

  const FaceMatchResultScreen({
    super.key,
    required this.userId,
    required this.userImagePath,
    required this.referenceImagePath,
  });

  @override
  State<FaceMatchResultScreen> createState() => _FaceMatchResultScreenState();
}

class _FaceMatchResultScreenState extends State<FaceMatchResultScreen>
    with SingleTickerProviderStateMixin {
  final VerificationApiService _verificationApiService = VerificationApiService();

  late final AnimationController _checkController;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkOpacity;

  Timer? _progressTimer;
  _MatchStage _stage = _MatchStage.verifying;
  double _progress = 0.08;
  double? _score;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _checkScale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeOutBack),
    );
    _checkOpacity = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOut,
    );

    _startProgressTicker();
    _runFaceMatch();
  }

  void _startProgressTicker() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted || _stage != _MatchStage.verifying) return;
      setState(() {
        _progress = (_progress + 0.015).clamp(0.08, 0.9);
      });
    });
  }

  Future<void> _runFaceMatch() async {
    try {
      final result = await _verificationApiService.verifyFaceMatch(
        userId: widget.userId,
        userImagePath: widget.userImagePath,
        refImagePath: widget.referenceImagePath,
        faceMatchScoreDeclineThreshold: 30,
        rotateImage: true,
      );

      if (!mounted) return;

      if (!result.isApproved) {
        _progressTimer?.cancel();
        setState(() {
          _stage = _MatchStage.failed;
          _score = result.score;
          _error = 'Face match not approved (${result.status}).';
        });
        return;
      }

      _progressTimer?.cancel();
      setState(() {
        _progress = 1.0;
        _score = result.score;
      });

      await Future<void>.delayed(const Duration(milliseconds: 380));
      if (!mounted) return;

      setState(() => _stage = _MatchStage.success);
      _checkController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      _progressTimer?.cancel();
      setState(() {
        _stage = _MatchStage.failed;
        _error = 'Face match failed: $e';
      });
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _stage == _MatchStage.verifying
                ? _buildVerifying()
                : _stage == _MatchStage.success
                    ? _buildSuccess(context)
                    : _buildFailure(context),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifying() {
    final percent = (_progress * 100).clamp(0, 100).round();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _pulseRing(132, 0.18),
              _pulseRing(104, 0.28),
              _pulseRing(76, 0.38),
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.center_focus_strong,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Verifying Match',
          style: TextStyle(
            color: AppColors.plum,
            fontSize: 38 / 1.73,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Comparing your face scan with your provided\nID document. This will just take a moment.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.ink.withValues(alpha: 0.78),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 34),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 195,
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 4,
              backgroundColor: const Color(0x40FF5A00),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Matching Biometrics... $percent%',
          style: const TextStyle(
            color: AppColors.orange,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final scoreText = _score == null ? '' : 'Score: ${_score!.toStringAsFixed(1)}';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeTransition(
          opacity: _checkOpacity,
          child: ScaleTransition(
            scale: _checkScale,
            child: Container(
              width: 112,
              height: 112,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3322C55E),
                    blurRadius: 22,
                    spreadRadius: 3,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 56,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Verification Success!',
          style: TextStyle(
            color: AppColors.plum,
            fontSize: 42 / 1.73,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Face and ID match confirmed.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 24 / 1.73,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (scoreText.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            scoreText,
            style: TextStyle(
              color: AppColors.ink.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFD7E8DE),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_outlined, size: 16, color: Color(0xFF1B7A47)),
              SizedBox(width: 6),
              Text(
                'Ka-Bayan Verified!',
                style: TextStyle(
                  color: Color(0xFF1B7A47),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 78),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.welcome,
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Get Started',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailure(BuildContext context) {
    final subtitle = _error ?? 'Face match failed. Please try again.';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: const BoxDecoration(
            color: Color(0xFFE85D5D),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 46),
        ),
        const SizedBox(height: 24),
        const Text(
          'Verification Failed',
          style: TextStyle(
            color: AppColors.plum,
            fontSize: 38 / 1.73,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.ink.withValues(alpha: 0.78),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pulseRing(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.orange.withValues(alpha: alpha), width: 1.2),
      ),
    );
  }
}
