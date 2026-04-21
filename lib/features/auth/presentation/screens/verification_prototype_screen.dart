import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/auth/presentation/screens/document_scan_prototype_screen.dart';

class VerificationPrototypeScreen extends StatelessWidget {
  const VerificationPrototypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 18, bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 57, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.deep,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Sign up',
                    style: TextStyle(
                      color: AppColors.deep,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      height: 1.17,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Padding(
              padding: EdgeInsets.fromLTRB(30, 0, 51, 0),
              child: Text(
                'Choose your\nverification document.',
                style: TextStyle(
                  color: AppColors.plum,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.32,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 17),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 45, 0),
              child: Column(
                children: [
                  _DocumentCard(
                    icon: Icons.credit_card,
                    title: 'National ID',
                    subtitle: 'Government issued',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const DocumentScanPrototypeScreen(documentLabel: 'National ID'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _DocumentCard(
                    icon: Icons.school_outlined,
                    title: 'Student ID',
                    subtitle: 'University issued',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const DocumentScanPrototypeScreen(documentLabel: 'Student ID'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _DocumentCard(
                    icon: Icons.badge_outlined,
                    title: "Driver's License",
                    subtitle: 'Government issued',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DocumentScanPrototypeScreen(
                          documentLabel: "Driver's License",
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DocumentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE7DB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.orange,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.plum,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.ink.withValues(alpha: 0.6),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0x1AFF5A00),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
