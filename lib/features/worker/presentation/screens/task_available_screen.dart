import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/widgets/kb_buttons.dart';
import 'package:kbsync/features/worker/data/worker_task_feed_service.dart';

class TaskAvailableScreen extends StatefulWidget {
  const TaskAvailableScreen({super.key});

  @override
  State<TaskAvailableScreen> createState() => _TaskAvailableScreenState();
}

class _TaskAvailableScreenState extends State<TaskAvailableScreen> {
  int _seconds = 15;
  Timer? _timer;

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
        child: Column(
          children: [
            _BackHeader(
              title: 'New Task Alert',
              onBack: () => Navigator.of(context).pop(),
            ),
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
                    KbGradientButton(
                      text: 'Accept Task',
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.evidenceLog),
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
        children: rows
            .asMap()
            .entries
            .map(
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
            )
            .toList(),
      ),
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
