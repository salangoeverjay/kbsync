import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/widgets/kb_buttons.dart';
import 'package:kbsync/features/auth/data/firebase_auth_service.dart';
import 'package:kbsync/features/worker/data/worker_lockout_service.dart';
import 'package:kbsync/features/worker/data/worker_task_feed_service.dart';
import 'package:kbsync/features/worker/presentation/screens/task_scan_screen.dart';
import 'package:kbsync/features/worker/presentation/widgets/worker_lockout_banner.dart';

class TaskAvailableScreen extends StatefulWidget {
  const TaskAvailableScreen({super.key});

  @override
  State<TaskAvailableScreen> createState() => _TaskAvailableScreenState();
}

class _TaskAvailableScreenState extends State<TaskAvailableScreen> {
  int _seconds = 15;
  Timer? _timer;
  final WorkerLockoutService _lockoutService = WorkerLockoutService();
  final FirebaseAuthService _authService = FirebaseAuthService();
  bool _isAccepting = false;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  /// Captures the worker's display name and routes to the entrance scan.
  /// The actual claim on the task (writing `worker`/`workerUid`) is deferred
  /// until the backend marks the scan passed — otherwise a failed scan would
  /// leave the task hidden from other workers and from the worker themselves.
  Future<void> _acceptAndScan(WorkerOpenTask task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    try {
      final fullName = await _authService.getCurrentUserFullName();
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed(
        AppRoutes.taskScan,
        arguments: TaskScanScreenArgs(
          taskId: task.id,
          mode: TaskScanMode.entrance,
          workerName: fullName ?? 'Worker',
          onPassRoute: AppRoutes.evidenceLog,
          onPassArguments: task.id,
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not start scan: $err')));
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds > 0) setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final task = route?.settings.arguments is WorkerOpenTask
        ? route!.settings.arguments as WorkerOpenTask
        : null;

    final title = task?.title ?? 'House Cleaning';
    final area = task?.areaLabel ?? 'Living Room';
    final service = task?.service ?? 'Cleaning';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: StreamBuilder<WorkerLockoutState>(
          stream: _currentUserId == null
              ? Stream<WorkerLockoutState>.value(WorkerLockoutState.empty)
              : _lockoutService.watchLockout(_currentUserId!),
          initialData: WorkerLockoutState.empty,
          builder: (context, lockoutSnap) {
            final lockoutState = lockoutSnap.data ?? WorkerLockoutState.empty;
            final locked = lockoutState.isLocked();

            void showLockoutSnack() {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'You are temporarily locked out from accepting tasks.',
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color(0xFFB91C1C),
                ),
              );
            }

            return Column(
              children: [
                _BackHeader(
                  title: 'New Task Alert',
                  onBack: () => Navigator.of(context).pop(),
                ),
                if (locked) WorkerLockoutBanner(state: lockoutState),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Column(
                      children: [
                        _CountdownRing(seconds: _seconds),
                        const SizedBox(height: 12),
                        _StatusChip(service: service),
                        const SizedBox(height: 10),
                        Text(
                          '$title\n$area',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                            letterSpacing: -1,
                            color: AppColors.plum,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _TaskDetailCard(task: task),
                        const SizedBox(height: 20),
                        Opacity(
                          opacity: (locked || _isAccepting) ? 0.5 : 1.0,
                          child: KbGradientButton(
                            text: locked
                                ? 'Locked Out'
                                : _isAccepting
                                ? 'Accepting…'
                                : 'Accept Task',
                            onTap: locked
                                ? showLockoutSnack
                                : (task == null || _isAccepting)
                                ? null
                                : () => _acceptAndScan(task),
                          ),
                        ),
                        const SizedBox(height: 10),
                        KbGhostButton(
                          text: 'Pass',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  final int seconds;
  const _CountdownRing({required this.seconds});

  @override
  Widget build(BuildContext context) {
    const total = 15;
    final pct = seconds / total;
    final circ = 2 * math.pi * 88;
    final offset = circ * (1 - pct);

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(200, 200),
            painter: _CountdownPainter(offset: offset, circ: circ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$seconds',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 60,
                  color: AppColors.plum,
                  height: 1,
                ),
              ),
              const Text(
                'seconds',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.plum,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountdownPainter extends CustomPainter {
  final double offset, circ;
  const _CountdownPainter({required this.offset, required this.circ});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const r = 88.0;

    final track = Paint()
      ..color = AppColors.orange.withValues(alpha: 0.15)
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, r, track);

    final fill = Paint()
      ..color = AppColors.orange
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      circ / r - offset / r,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(_CountdownPainter old) => old.offset != offset;
}

class _StatusChip extends StatelessWidget {
  final String service;

  const _StatusChip({required this.service});

  String get _label {
    final normalized = service.toUpperCase();
    return '$normalized WORK AVAILABLE';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.orange,
        ),
      ),
    );
  }
}

class _TaskDetailCard extends StatelessWidget {
  final WorkerOpenTask? task;

  const _TaskDetailCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      (
        'Service',
        '${task?.service ?? 'House Cleaning'}: ${task?.areaLabel ?? 'Living Room'}',
      ),
      ('Complexity', task?.complexity ?? 'Moderate'),
      ('Total Payout', task?.total ?? '₱207.00'),
      ('Mode', (task?.mode ?? 'standard').toUpperCase()),
      if (task?.requiresMerchantQrPayment == true)
        ('Payment', 'Direct merchant payment via QR'),
      if ((task?.groceryListLabel ?? '').trim().isNotEmpty)
        ('Buy List', task!.groceryListLabel),
      if ((task?.groceryBudgetLabel ?? '').trim().isNotEmpty)
        ('Budget', task!.groceryBudgetLabel),
      if ((task?.cleaningTargets ?? const <String>[]).isNotEmpty)
        ('What to clean', task!.cleaningTargets.join(', ')),
      if ((task?.notes ?? '').trim().isNotEmpty)
        ('Notes', (task?.notes ?? '').trim()),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rows.asMap().entries.map(
            (e) => Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: e.key < rows.length - 1
                    ? Border(bottom: BorderSide(color: AppColors.border))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.value.$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink.withValues(alpha: 0.5),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      e.value.$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.plum,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if ((task?.referencePhotoUrl ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reference Photo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildReferencePhoto(task!.referencePhotoUrl),
            ),
          ],
        ],
      ),
    );
  }

  // Reference photos are stored either as a remote https URL (legacy /
  // pre-Spark-pivot) or as a `data:image/jpeg;base64,...` URI embedded in
  // the task doc. Decode and render with the right widget.
  //
  // Cache the decoded bytes keyed by the data: URI so unrelated parent
  // rebuilds (lockout-banner countdown, etc.) don't re-decode and cause
  // the image to flicker between frames.
  static final Map<String, Uint8List> _decodedRefPhotoCache =
      <String, Uint8List>{};

  Widget _buildReferencePhoto(String src) {
    final fallback = Container(
      height: 90,
      alignment: Alignment.center,
      color: AppColors.border.withValues(alpha: 0.3),
      child: const Text('Unable to load photo'),
    );

    if (src.startsWith('data:')) {
      final commaIdx = src.indexOf(',');
      if (commaIdx == -1) return fallback;
      Uint8List? bytes = _decodedRefPhotoCache[src];
      if (bytes == null) {
        try {
          bytes = base64Decode(src.substring(commaIdx + 1));
          _decodedRefPhotoCache[src] = bytes;
        } catch (_) {
          return fallback;
        }
      }
      return Image.memory(
        bytes,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, error, stackTrace) => fallback,
      );
    }

    return Image.network(
      src,
      height: 150,
      width: double.infinity,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, error, stackTrace) => fallback,
    );
  }
}

class _BackHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _BackHeader({required this.title, required this.onBack});

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
                color: AppColors.plum.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 16,
                color: AppColors.plum,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: AppColors.ink,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}
