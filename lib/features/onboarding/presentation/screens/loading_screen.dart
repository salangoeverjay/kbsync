import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kbsync/features/auth/data/firebase_auth_service.dart';
import 'package:kbsync/core/theme/app_colors.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  static const _loadingDuration = Duration(milliseconds: 2400);

  late final Timer _routeTimer;
  late final AnimationController _orb1Ctrl;
  late final AnimationController _orb2Ctrl;
  late final AnimationController _ringCtrl;
  late final AnimationController _logoCtrl;
  late final Animation<double> _orb1;
  late final Animation<double> _orb2;
  late final Animation<double> _logo;

  bool _logoReady = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    try {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.bottom],
      );
    } catch (_) {}

    _orb1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _orb2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _orb1 = Tween<double>(
      begin: 0,
      end: -10,
    ).animate(CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));
    _orb2 = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));
    _logo = Tween<double>(
      begin: 0,
      end: -6,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOut));

    _logoReady = true;
    _routeTimer = Timer(_loadingDuration, () => _goToWelcome());
  }

  Future<void> _goToWelcome() async {
    if (!mounted || _navigated) return;
    _navigated = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // user already signed in — resolve role and navigate to correct home
        final authService = FirebaseAuthService();
        final verification = await authService.getVerificationState(
          uid: user.uid,
        );
        final role = verification?.role?.trim().toLowerCase();
        if (role == 'resident') {
          if (!mounted) return;
          Navigator.of(
            context,
          ).pushReplacementNamed(AppRoutes.residentDashboard);
          return;
        }
        // default to worker dashboard for any other role or missing role
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRoutes.workerDashboard);
        return;
      }
    } catch (_) {
      // ignore and fall back to welcome
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
  }

  @override
  void dispose() {
    _routeTimer.cancel();
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _ringCtrl.dispose();
    _logoCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deep,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goToWelcome(),
        child: Stack(
          children: [
            // Radial gradient overlays
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.6, -0.7),
                    radius: 1.1,
                    colors: [
                      AppColors.plum.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.7, 0.6),
                    radius: 1.0,
                    colors: [
                      AppColors.orange.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Background grid
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),

            // Floating orbs
            AnimatedBuilder(
              animation: _orb1,
              builder: (_, _) => Positioned(
                top: 80 + _orb1.value,
                right: -60,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.orange.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _orb2,
              builder: (_, _) => Positioned(
                bottom: 120 + _orb2.value,
                left: -50,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.plum.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Center content
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Hero halo + rotating ring + logo
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer pulsing halo
                          Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.orange.withValues(alpha: 0.22),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          // Rotating dashed ring
                          AnimatedBuilder(
                            animation: _ringCtrl,
                            builder: (_, _) => Transform.rotate(
                              angle: _ringCtrl.value * 2 * math.pi,
                              child: CustomPaint(
                                size: const Size(220, 220),
                                painter: _DashedRingPainter(),
                              ),
                            ),
                          ),
                          // Inner soft ring
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.04),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                                width: 1,
                              ),
                            ),
                          ),
                          // Floating logo (fades in once cached)
                          AnimatedBuilder(
                            animation: _logo,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(0, _logo.value),
                              child: child,
                            ),
                            child: AnimatedOpacity(
                              opacity: _logoReady ? 1 : 0,
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOut,
                              child: AnimatedScale(
                                scale: _logoReady ? 1 : 0.92,
                                duration: const Duration(milliseconds: 360),
                                curve: Curves.easeOutBack,
                                child: SizedBox(
                                  width: 138,
                                  height: 158,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Image.asset(
                                      'assets/images/Kabayansynclogo.png',
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true,
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Wordmark
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.orange,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'KA-BAYAN SYNC',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // Gradient progress
                    SizedBox(
                      width: 200,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: _loadingDuration,
                        curve: Curves.easeInOut,
                        builder: (context, value, _) {
                          return Stack(
                            children: [
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: value,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.grad,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.orange.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 10,
                                        spreadRadius: 0,
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

                    const SizedBox(height: 14),

                    Text(
                      'Connecting your neighborhood…',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
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
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

class _DashedRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const totalDashes = 48;
    for (var i = 0; i < totalDashes; i++) {
      final t = i / totalDashes;
      final start = t * 2 * math.pi;
      final sweep = (2 * math.pi / totalDashes) * 0.55;
      // Alternate between orange and faint white for a tasteful ring
      paint.color = i % 4 == 0
          ? AppColors.orange.withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.18);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter oldDelegate) => false;
}
