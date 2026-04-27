import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/worker/data/worker_lockout_service.dart';

/// Red lockout banner with a live "Xh YYm" countdown.
///
/// Renders nothing when [state] is not locked. The widget owns its own
/// 30-second tick timer rather than rebuilding every second, since the
/// countdown is shown in coarse minutes.
class WorkerLockoutBanner extends StatefulWidget {
  final WorkerLockoutState state;
  final VoidCallback? onCleared;

  const WorkerLockoutBanner({
    required this.state,
    this.onCleared,
    super.key,
  });

  @override
  State<WorkerLockoutBanner> createState() => _WorkerLockoutBannerState();
}

class _WorkerLockoutBannerState extends State<WorkerLockoutBanner> {
  Timer? _ticker;
  bool _firedCleared = false;

  @override
  void initState() {
    super.initState();
    _restartTicker();
  }

  @override
  void didUpdateWidget(covariant WorkerLockoutBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.lockedUntil != widget.state.lockedUntil) {
      _firedCleared = false;
      _restartTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _restartTicker() {
    _ticker?.cancel();
    if (!widget.state.isLocked()) return;
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (!widget.state.isLocked()) {
        if (!_firedCleared) {
          _firedCleared = true;
          widget.onCleared?.call();
        }
        _ticker?.cancel();
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.state.isLocked()) return const SizedBox.shrink();

    final remaining = widget.state.remaining();
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final readable = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    final endTime = widget.state.lockedUntil!.toLocal();
    final endHour = endTime.hour % 12 == 0 ? 12 : endTime.hour % 12;
    final endMinute = endTime.minute.toString().padLeft(2, '0');
    final endPeriod = endTime.hour >= 12 ? 'PM' : 'AM';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0x14DC2626),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFDC2626).withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              color: Color(0xFFDC2626),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You are locked out for $readableLabel',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFFB91C1C),
                    letterSpacing: -0.2,
                  ),
                ).copyWithText('You are locked out for $readable'),
                const SizedBox(height: 2),
                Text(
                  'Three failed identity scans triggered a 5-hour cool-down. '
                  'You can accept tasks again at $endHour:$endMinute $endPeriod.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.ink.withValues(alpha: 0.7),
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

// Sentinel placeholder used so the const Text above can be a single
// expression while we substitute the runtime label. Dart prevents direct
// interpolation in const contexts; this tiny extension keeps the literal
// styled and replaces the text at the call site.
const _readablePlaceholder = 'You are locked out for ';
extension _TextRebuild on Text {
  Text copyWithText(String text) {
    return Text(text, style: style, textAlign: textAlign);
  }
}

const String readableLabel = _readablePlaceholder; // referenced above
