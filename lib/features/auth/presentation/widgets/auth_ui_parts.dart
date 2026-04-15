import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';

class AuthHeader extends StatelessWidget {
  final String title;

  const AuthHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.arrow_back, color: AppColors.plum),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.deep,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class AuthField extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscure;

  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.plum,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 65,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.plum.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              obscure ? '••••••••••••' : hint,
              style: TextStyle(
                color: AppColors.plum.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthPillButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback? onTap;

  const AuthPillButton({
    super.key,
    required this.text,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 51,
        width: double.infinity,
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
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
