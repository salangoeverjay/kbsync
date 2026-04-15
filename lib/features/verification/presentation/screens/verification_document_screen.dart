import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/verification/presentation/screens/verify_document_screen.dart';

class VerificationDocumentScreen extends StatelessWidget {
  const VerificationDocumentScreen({super.key});

  Future<void> _onSelect(BuildContext context, String documentType) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerifyDocumentScreen(documentType: documentType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(30, 18, 30, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushReplacementNamed(AppRoutes.welcome),
                  icon: const Icon(Icons.arrow_back, color: AppColors.deep),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 24,
                    height: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Verification',
                  style: TextStyle(
                    color: AppColors.deep,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 321,
              child: Text(
                'Choose your\nverification document.',
                style: TextStyle(
                  color: AppColors.plum,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 39.6 / 30,
                ),
              ),
            ),
            const SizedBox(height: 22),
            _DocumentCard(
              title: 'National ID',
              subtitle: 'Government issued',
              icon: Icons.credit_card,
              onTap: () => _onSelect(context, 'National ID'),
            ),
            const SizedBox(height: 24),
            _DocumentCard(
              title: 'Student ID',
              subtitle: 'University issued',
              icon: Icons.school_outlined,
              onTap: () => _onSelect(context, 'Student ID'),
            ),
            const SizedBox(height: 24),
            _DocumentCard(
              title: "Philippines Driver's License",
              subtitle: 'LTO issued',
              icon: Icons.directions_car_outlined,
              onTap: () => _onSelect(context, "Philippines Driver's License"),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _DocumentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE7DB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: AppColors.orange, size: 32),
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
                    Opacity(
                      opacity: 0.6,
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0x1AFF5A00),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.chevron_right,
                  color: AppColors.orange,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
