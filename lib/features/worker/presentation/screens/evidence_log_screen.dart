import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/worker/data/evidence_service.dart';
import 'package:kbsync/features/worker/presentation/screens/task_scan_screen.dart';

class EvidenceLogScreen extends StatefulWidget {
  const EvidenceLogScreen({super.key});

  @override
  State<EvidenceLogScreen> createState() => _EvidenceLogScreenState();
}

class _EvidenceLogScreenState extends State<EvidenceLogScreen>
    with WidgetsBindingObserver {
  final EvidenceService _evidenceService = EvidenceService();

  CameraController? _cameraController;
  bool _isInitializing = true;
  String? _cameraError;
  bool _flash = false;
  bool _isCapturing = false;
  int _capturedCount = 0;

  Stream<Position?> _watchWorkerLocation() async* {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      yield null;
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      yield null;
      return;
    }

    yield await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeRearCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.dispose();
      _cameraController = null;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _initializeRearCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeRearCamera({int attempt = 0}) async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _cameraError = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
          'NoCameraFound',
          'No camera is available on this device.',
        );
      }
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final old = _cameraController;
      setState(() {
        _cameraController = controller;
        _isInitializing = false;
      });
      await old?.dispose();
    } on CameraException catch (e) {
      // Retry once if the previous screen's camera is still releasing.
      // Phones cap concurrent open cameras at 1; the prior front-camera
      // dispose can race with our open call here.
      final isInUse =
          (e.code == 'CameraAccessDenied' ||
              e.code == 'CameraAccess' ||
              e.code == 'cameraNotReadable' ||
              (e.description ?? '').toLowerCase().contains('in use')) &&
          attempt == 0;
      if (isInUse) {
        await Future.delayed(const Duration(milliseconds: 600));
        return _initializeRearCamera(attempt: 1);
      }
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _cameraController = null;
        _cameraError = e.description ?? 'Unable to start the camera.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _cameraController = null;
        _cameraError = 'Unable to start the camera.';
      });
    }
  }

  Future<void> _goToExitScan() async {
    final taskId = ModalRoute.of(context)?.settings.arguments as String?;
    if (taskId == null || taskId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Missing task context. Reopen this task from your dashboard.',
          ),
        ),
      );
      return;
    }

    // Release the rear camera before the exit scan opens the front camera —
    // Android caps concurrent open cameras at 1.
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }

    if (!mounted) return;
    await Navigator.of(context).pushReplacementNamed(
      AppRoutes.taskScan,
      arguments: TaskScanScreenArgs(
        taskId: taskId,
        mode: TaskScanMode.exit,
        onPassRoute: AppRoutes.completionSummary,
        onPassArguments: taskId,
      ),
    );
  }

  Future<void> _shoot() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }
    final taskId = ModalRoute.of(context)?.settings.arguments as String?;
    if (taskId == null || taskId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Missing task context. Reopen this task from your dashboard.',
          ),
        ),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in expired. Please sign in again.')),
      );
      return;
    }

    setState(() {
      _isCapturing = true;
      _flash = true;
    });
    try {
      final picture = await controller.takePicture();
      await _evidenceService.uploadFromFile(
        taskId: taskId,
        workerUid: user.uid,
        filePath: picture.path,
      );
      if (!mounted) return;
      setState(() {
        _capturedCount += 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Evidence #$_capturedCount saved.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.plum,
          duration: const Duration(milliseconds: 1200),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
        // Tail the flash a touch so the screen blinks like a real shutter.
        Future.delayed(const Duration(milliseconds: 220), () {
          if (mounted) setState(() => _flash = false);
        });
      }
    }
  }

  Widget _buildCameraPreview() {
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                size: 36,
                color: Colors.white70,
              ),
              const SizedBox(height: 10),
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _initializeRearCamera,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: AppColors.orange),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_isInitializing || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
        ),
      );
    }
    return CameraPreview(_cameraController!);
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Evidence Log',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.greenLt.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          size: 12,
                          color: AppColors.green,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'SECURE',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 1,
                            color: AppColors.green,
                          ),
                        ),
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
                  // Live camera preview
                  Positioned.fill(child: _buildCameraPreview()),
                  // Captured-count chip
                  if (_capturedCount > 0)
                    Positioned(
                      top: 36,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.plum.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$_capturedCount captured',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  // GPS watermark
                  Positioned(
                    top: 8,
                    left: 52,
                    right: 52,
                    child: StreamBuilder<Position?>(
                      stream: _watchWorkerLocation(),
                      builder: (context, snapshot) {
                        final position = snapshot.data;
                        final timestamp = _formatWatermarkTime(DateTime.now());
                        final label = position == null
                            ? 'LIVE GPS | Location unavailable | $timestamp'
                            : 'LIVE GPS | ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)} | $timestamp';

                        return Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                                letterSpacing: 0.8,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Flash overlay
                  if (_flash)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  // Verification widget — only after the first capture.
                  if (_capturedCount > 0)
                    Positioned(
                      bottom: 100,
                      left: 16,
                      right: 16,
                      child: _VerificationWidget(capturedCount: _capturedCount),
                    ),
                  // Camera controls
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CtrlBtn(icon: Icons.flash_on_rounded, onTap: () {}),
                        const SizedBox(width: 44),
                        // Shutter
                        Opacity(
                          opacity:
                              (_isCapturing ||
                                  _isInitializing ||
                                  _cameraController == null)
                              ? 0.5
                              : 1.0,
                          child: GestureDetector(
                            onTap: _shoot,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: AppColors.plum,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.plum.withValues(alpha: 0.35),
                                  width: 5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.plum.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 28,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: _isCapturing
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 44),
                        _CtrlBtn(
                          icon: Icons.flip_camera_android_rounded,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom action — disabled until at least 1 evidence photo.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              color: const Color(0xFF111018),
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _capturedCount >= 1
                        ? AppColors.plum
                        : AppColors.plum.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _capturedCount >= 1 ? _goToExitScan : null,
                    child: Center(
                      child: Text(
                        _capturedCount >= 1
                            ? 'Request Client Verification'
                            : 'Capture at least 1 evidence photo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
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

  String _formatWatermarkTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final year = (time.year % 100).toString().padLeft(2, '0');
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$month.$day.$year | ${hour.toString().padLeft(2, '0')}:$minute $period';
  }
}

class _VerificationWidget extends StatelessWidget {
  const _VerificationWidget({required this.capturedCount});

  final int capturedCount;

  @override
  Widget build(BuildContext context) {
    // 0 photos = 0%, 1 photo = 50%, 2+ = 100%.
    final progress = capturedCount >= 2 ? 1.0 : capturedCount * 0.5;
    final percent = (progress * 100).round();
    final label = progress >= 1.0 ? 'Verified' : 'Verifying...';
    final visualOn = capturedCount >= 1;
    final locationOn = capturedCount >= 1;
    final proofOn = capturedCount >= 2;

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
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.8,
                  color: AppColors.plum,
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.plum,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.bg,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.plumDeep,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _VerifyItem('Visual\nAuthenticity', on: visualOn),
              _VerifyItem('Location\nAccuracy', on: locationOn),
              _VerifyItem('Digital Proof\nSecured', on: proofOn),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerifyItem extends StatelessWidget {
  final String label;
  final bool on;
  const _VerifyItem(this.label, {this.on = false});

  @override
  Widget build(BuildContext context) {
    final color = on ? const Color(0xFF22C55E) : Colors.black26;
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: on ? AppColors.ink : Colors.black45,
            height: 1.4,
          ),
        ),
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.orange),
      ),
    );
  }
}
