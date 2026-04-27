import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';

class NeighborhoodWelcomeScreen extends StatefulWidget {
  const NeighborhoodWelcomeScreen({super.key});

  @override
  State<NeighborhoodWelcomeScreen> createState() => _NeighborhoodWelcomeScreenState();
}

class _NeighborhoodWelcomeScreenState extends State<NeighborhoodWelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _orb1Ctrl;
  late final AnimationController _orb2Ctrl;
  late final AnimationController _heroCtrl;
  late final Animation<double> _orb1;
  late final Animation<double> _orb2;
  late final Animation<double> _hero;

  @override
  void initState() {
    super.initState();
    _orb1Ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _orb2Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000))
      ..repeat(reverse: true);
    _heroCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);

    _orb1 = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut),
    );
    _orb2 = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut),
    );
    _hero = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _heroCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _heroCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deep,
      body: Stack(
        children: [
          // Radial gradient overlays
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.6),
                  radius: 1.0,
                  colors: [const Color(0x40EC5914), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.6, 0.6),
                  radius: 1.0,
                  colors: [const Color(0x66911B44), Colors.transparent],
                ),
              ),
            ),
          ),
          // Grid pattern
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),
          // Floating orb 1 — top right
          AnimatedBuilder(
            animation: _orb1,
            builder: (context, _) => Positioned(
              top: 60 + _orb1.value,
              right: -30,
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x33EC5914), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          // Floating orb 2 — top left
          AnimatedBuilder(
            animation: _orb2,
            builder: (context, _) => Positioned(
              top: 160 + _orb2.value,
              left: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x4D911B44), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo pill
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shield_rounded, size: 14, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'KA-BAYAN SYNC',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Color(0xD9FFFFFF),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Hero illustration (centered in remaining space above bottom sheet)
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _hero,
                      builder: (context, _) => Transform.translate(
                        offset: Offset(0, _hero.value),
                        child: SizedBox(
                          width: 280,
                          height: 280,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer orbit ring
                              Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0x4DEC5914),
                                    width: 2,
                                  ),
                                ),
                              ),
                              // Inner filled circle
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0x1AEC5914),
                                  border: Border.all(
                                    color: const Color(0x33EC5914),
                                    width: 2,
                                  ),
                                ),
                                child: const Center(
                                  child: Text('🏘️', style: TextStyle(fontSize: 64)),
                                ),
                              ),
                              // Orbiting dots
                              ..._orbitDots(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom content
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Panabo City, Davao del Norte',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.orange,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          text: 'Welcome to the\n',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 36,
                            height: 40 / 36,
                            letterSpacing: -1.5,
                            color: Colors.white,
                          ),
                          children: [
                            TextSpan(
                              text: 'Neighborhood.',
                              style: const TextStyle(color: AppColors.orange),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Connect with verified locals. Offer your skills and build a stronger community together.',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                          height: 22 / 15,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 36),
                      _GradientButton(
                        text: 'Join Ka-Bayan Sync',
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.signUp),
                      ),
                      const SizedBox(height: 12),
                      _GhostButton(
                        text: 'I already have an account',
                        onTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.login),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _orbitDots() {
    const degrees = [0, 60, 120, 180, 240, 300];
    const r = 0.44 * 140.0; // 44% of half of 280px container
    return degrees.asMap().entries.map((e) {
      final i = e.key;
      final angle = e.value * math.pi / 180;
      return Positioned(
        top: 140 + r * math.sin(angle) - 4,
        left: 140 + r * math.cos(angle) - 4,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i % 2 == 0 ? AppColors.orange : Colors.white.withValues(alpha: 0.3),
          ),
        ),
      );
    }).toList();
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

class _GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _GradientButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.grad,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66EC5914),
              blurRadius: 28,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _GhostButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
