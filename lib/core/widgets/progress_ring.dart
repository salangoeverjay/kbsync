import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';

class ProgressRing extends StatelessWidget {
  final double percent;
  final double size;
  final double strokeWidth;
  final Color fillColor;
  final Color trackColor;
  final Widget? child;

  const ProgressRing({
    required this.percent,
    this.size = 80,
    this.strokeWidth = 8,
    this.fillColor = AppColors.plum,
    this.trackColor = const Color(0x1A911B44),
    this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              percent: percent,
              strokeWidth: strokeWidth,
              fillColor: fillColor,
              trackColor: trackColor,
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final double strokeWidth;
  final Color fillColor;
  final Color trackColor;

  const _RingPainter({
    required this.percent,
    required this.strokeWidth,
    required this.fillColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final fillPaint = Paint()
      ..color = fillColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * (percent / 100),
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.percent != percent || old.fillColor != fillColor;
}

class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const DashedCirclePainter({required this.color, this.strokeWidth = 1.5});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;
    final circumference = 2 * math.pi * radius;
    const dashCount = 24;
    final dashAngle = (circumference / dashCount) / radius;
    final gapAngle = dashAngle * 0.6;
    final stepAngle = dashAngle + gapAngle;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * stepAngle - math.pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(DashedCirclePainter old) => old.color != color;
}
