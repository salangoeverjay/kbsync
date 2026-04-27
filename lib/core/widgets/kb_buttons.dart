import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';

class KbGradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final double height;
  final double borderRadius;
  final double fontSize;

  const KbGradientButton({
    required this.text,
    required this.onTap,
    this.height = 52,
    this.borderRadius = 14,
    this.fontSize = 15,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.grad,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.plum.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class KbGhostButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final double height;

  const KbGhostButton({
    required this.text,
    required this.onTap,
    this.height = 52,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.plum.withValues(alpha: 0.25),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.plum,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class KbStatusTag extends StatelessWidget {
  final String text;
  final _TagColor _tagColor;

  const KbStatusTag.green(this.text, {super.key}) : _tagColor = _TagColor.green;
  const KbStatusTag.orange(this.text, {super.key}) : _tagColor = _TagColor.orange;
  const KbStatusTag.plum(this.text, {super.key}) : _tagColor = _TagColor.plum;
  const KbStatusTag.red(this.text, {super.key}) : _tagColor = _TagColor.red;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (_tagColor) {
      _TagColor.green => (const Color(0x66AFE4DC), AppColors.green),
      _TagColor.orange => (const Color(0x1FEC5914), AppColors.orange),
      _TagColor.plum => (const Color(0x1A911B44), AppColors.plum),
      _TagColor.red => (const Color(0x1AEF4444), const Color(0xFFDC2626)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: fg,
        ),
      ),
    );
  }
}

enum _TagColor { green, orange, plum, red }
