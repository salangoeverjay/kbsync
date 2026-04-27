import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';

class EvidenceLogScreen extends StatefulWidget {
  const EvidenceLogScreen({super.key});

  @override
  State<EvidenceLogScreen> createState() => _EvidenceLogScreenState();
}

class _EvidenceLogScreenState extends State<EvidenceLogScreen> {
  bool _captured = false;
  bool _flash = false;

  void _shoot() {
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) setState(() { _flash = false; _captured = true; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            // Dark header
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('Evidence Log', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white, letterSpacing: -0.4)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.greenLt.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(999)),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_rounded, size: 12, color: AppColors.green),
                        SizedBox(width: 5),
                        Text('SECURE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 1, color: AppColors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),
            // Camera viewfinder
            Expanded(
              child: Stack(
                children: [
                  // Background
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF111018), Color(0xFF0D0A14)],
                        ),
                      ),
                    ),
                  ),
                  // Content placeholder
                  if (_captured)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🧹', style: TextStyle(fontSize: 72)),
                          const SizedBox(height: 8),
                          Text('CAPTURED', style: TextStyle(fontFamily: 'PublicSans', fontWeight: FontWeight.w600, fontSize: 11, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 2)),
                        ],
                      ),
                    )
                  else
                    Center(child: Text('📷', style: TextStyle(fontSize: 80, color: Colors.white.withValues(alpha: 0.1)))),
                  // GPS watermark
                  Positioned(
                    top: 8, left: 52, right: 52,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          'SAHUR SUBD. BRGY. STO. NIÑO | 04.07.26 | 10:15',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 9, letterSpacing: 0.8, color: Colors.white.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                  ),
                  // Flash overlay
                  if (_flash) Positioned.fill(child: Container(color: Colors.white.withValues(alpha: 0.85))),
                  // Verification widget
                  Positioned(
                    bottom: 100,
                    left: 16, right: 16,
                    child: _VerificationWidget(),
                  ),
                  // Camera controls
                  Positioned(
                    bottom: 20,
                    left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CtrlBtn(icon: Icons.flash_on_rounded, onTap: () {}),
                        const SizedBox(width: 44),
                        // Shutter
                        GestureDetector(
                          onTap: _shoot,
                          child: Container(
                            width: 70, height: 70,
                            decoration: BoxDecoration(
                              color: AppColors.plum,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.plum.withValues(alpha: 0.35), width: 5),
                              boxShadow: [BoxShadow(color: AppColors.plum.withValues(alpha: 0.4), blurRadius: 28, offset: const Offset(0, 8))],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 24, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 44),
                        _CtrlBtn(icon: Icons.flip_camera_android_rounded, onTap: () {}),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom action
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              color: const Color(0xFF111018),
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(color: AppColors.plum, borderRadius: BorderRadius.circular(14)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.completionSummary),
                    child: const Center(
                      child: Text('Request Client Verification', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Verifying...', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.8, color: AppColors.plum)),
              const Text('100%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.plum)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(
              value: 1.0,
              minHeight: 7,
              backgroundColor: AppColors.bg,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.plumDeep),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _VerifyItem('Visual\nAuthenticity'),
              _VerifyItem('Location\nAccuracy'),
              _VerifyItem('Digital Proof\nSecured'),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerifyItem extends StatelessWidget {
  final String label;
  const _VerifyItem(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.4)),
      ],
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.3), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: AppColors.orange),
      ),
    );
  }
}
