import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/widgets/kb_buttons.dart';

class CompletionSummaryScreen extends StatefulWidget {
  const CompletionSummaryScreen({super.key});

  @override
  State<CompletionSummaryScreen> createState() => _CompletionSummaryScreenState();
}

class _CompletionSummaryScreenState extends State<CompletionSummaryScreen> {
  int _rating = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Plum header
          Container(
            color: AppColors.plum,
            child: SafeArea(
              bottom: false,
              child: _SummaryHeader(onBack: () => Navigator.of(context).pop()),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Worker banner
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(gradient: AppColors.grad, borderRadius: BorderRadius.circular(16)),
                          child: const Center(child: Text('J', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22))),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TASK COMPLETED!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.6, color: AppColors.plum)),
                            Text('Please verify the details below', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.orange)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 160),
                    child: Column(
                      children: [
                        const _TaskLogsCard(),
                        const SizedBox(height: 14),
                        const _TaskDetailsCard(),
                        const SizedBox(height: 14),
                        _RatingCard(rating: _rating, onRate: (r) => setState(() => _rating = r)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _StickyActions(onProceed: () => Navigator.of(context).pushReplacementNamed(AppRoutes.workerDashboard)),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _SummaryHeader({required this.onBack});

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
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          const Text('Completion Summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white, letterSpacing: -0.4)),
        ],
      ),
    );
  }
}

class _TaskLogsCard extends StatelessWidget {
  const _TaskLogsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Task Logs', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.4, color: AppColors.ink)),
          const SizedBox(height: 12),
          Row(
            children: [
              _LogTile(label: 'BEFORE', emoji: '🏚️', gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF3C1226), Color(0xFF911B44)],
              )),
              const SizedBox(width: 10),
              _LogTile(label: 'AFTER', emoji: '✨', gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF006C4F), Color(0xFF0891B2)],
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final String label, emoji;
  final LinearGradient gradient;
  const _LogTile({required this.label, required this.emoji, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 150,
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(14)),
        child: Stack(
          children: [
            Center(child: Text(emoji, style: TextStyle(fontSize: 44, color: Colors.white.withValues(alpha: 0.6)))),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white, letterSpacing: 1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskDetailsCard extends StatelessWidget {
  const _TaskDetailsCard();

  static const _rows = [
    ('Service Category', 'House Cleaning', false),
    ('Geo-Coordinate', '7.3051 N, 125.6792 E', false),
    ('Authentication', '100% Secure & Matched', false),
    ('Labor Duration', '1h 15m (09:00 – 10:15)', false),
    ('Total Earned', '₱207.00', true),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Task Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink)),
          const SizedBox(height: 8),
          ..._rows.asMap().entries.map((e) => Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: e.key < _rows.length - 1 ? Border(bottom: BorderSide(color: AppColors.border)) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.value.$1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.ink.withValues(alpha: 0.5))),
                Text(e.value.$2, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: e.value.$3 ? AppColors.green : AppColors.plum)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRate;
  const _RatingCard({required this.rating, required this.onRate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rate your experience', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.ink)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => onRate(i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.star_rounded,
                  size: 36,
                  color: i < rating ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }
}

class _StickyActions extends StatelessWidget {
  final VoidCallback onProceed;
  const _StickyActions({required this.onProceed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.transparent,
        gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [AppColors.bg, AppColors.bg.withValues(alpha: 0)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '*By continuing, you confirm the task is complete.',
            style: TextStyle(fontFamily: 'PublicSans', fontSize: 11, color: AppColors.ink.withValues(alpha: 0.5), letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          KbGradientButton(text: 'Proceed to Payment', onTap: onProceed),
          const SizedBox(height: 10),
          KbGhostButton(text: 'Report a Problem', onTap: () {}),
        ],
      ),
    );
  }
}
