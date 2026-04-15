import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kbsync/core/routing/app_routes.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  static const _background = Color(0xFFF3F3F3);
  static const _logoUrl = 'https://www.figma.com/api/mcp/asset/306d3d6c-543c-4bd3-8e16-258db1b729af';
  static const _loadingDuration = Duration(milliseconds: 1800);
  late final Timer _routeTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    try {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.bottom],
      );
    } catch (_) {
      // Ignore if the current platform does not support this overlay config.
    }
    _routeTimer = Timer(_loadingDuration, _goToWelcome);
  }

  void _goToWelcome() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
  }

  @override
  void dispose() {
    _routeTimer.cancel();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _goToWelcome,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 194,
                  height: 222,
                  child: Image.network(_logoUrl, fit: BoxFit.cover),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 180,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: _loadingDuration,
                    builder: (context, value, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFE2D8E8),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF911B44)),
                        ),
                      );
                    },
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
