import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/widgets/kb_buttons.dart';
import 'package:kbsync/features/worker/data/worker_task_scan_service.dart';

/// Whether this scan starts a task or finishes one.
enum TaskScanMode { entrance, exit }

class TaskScanScreenArgs {
  final String taskId;
  final TaskScanMode mode;

  /// Display name of the worker, surfaced to the resident on a passing
  /// entrance scan. Optional for exit scans (the worker is already
  /// assigned by then).
  final String? workerName;

  /// Route the screen pushes when the scan passes.
  /// (Entrance -> evidence; exit -> completion summary.)
  final String onPassRoute;

  /// Optional arguments handed to the next screen via `pushReplacementNamed`.
  final Object? onPassArguments;

  const TaskScanScreenArgs({
    required this.taskId,
    required this.mode,
    required this.onPassRoute,
    this.workerName,
    this.onPassArguments,
  });
}

class TaskScanScreen extends StatefulWidget {
  final TaskScanScreenArgs args;

  const TaskScanScreen({required this.args, super.key});

  @override
  State<TaskScanScreen> createState() => _TaskScanScreenState();
}

class _TaskScanScreenState extends State<TaskScanScreen>
    with WidgetsBindingObserver {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: false,
      enableLandmarks: false,
    ),
  );
  final WorkerTaskScanService _scanService = WorkerTaskScanService();

  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _isFaceDetected = false;
  bool _isProcessingFrame = false;
  bool _isSubmitting = false;
  String? _cameraError;
  String? _statusMessage;
  WorkerTaskScanResult? _lastResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFrontCamera();
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
      _initializeFrontCamera();
    }
  }

  Future<void> _initializeFrontCamera({int attempt = 0}) async {
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
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      await controller.startImageStream(_processCameraImage);

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
      // Phones cap concurrent open cameras at 1; if the prior screen's
      // rear camera is still releasing, retry once after a short delay.
      final isInUse = (e.code == 'CameraAccessDenied' ||
              e.code == 'CameraAccess' ||
              e.code == 'cameraNotReadable' ||
              (e.description ?? '').toLowerCase().contains('in use')) &&
          attempt == 0;
      if (isInUse) {
        await Future.delayed(const Duration(milliseconds: 600));
        return _initializeFrontCamera(attempt: 1);
      }
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _cameraController = null;
        _cameraError = e.description ?? 'Unable to start front camera.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _cameraController = null;
        _cameraError = 'Unable to start front camera.';
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingFrame) return;
    final controller = _cameraController;
    if (controller == null) return;

    _isProcessingFrame = true;
    try {
      final inputImage = _toInputImage(image, controller.description);
      final faces = await _faceDetector.processImage(inputImage);
      final detected = faces.isNotEmpty;
      if (mounted && detected != _isFaceDetected) {
        setState(() => _isFaceDetected = detected);
      }
    } catch (_) {
      // Single-frame failure — ignore.
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage _toInputImage(CameraImage image, CameraDescription description) {
    final writeBuffer = WriteBuffer();
    for (final plane in image.planes) {
      writeBuffer.putUint8List(plane.bytes);
    }
    final bytes = writeBuffer.done().buffer.asUint8List();

    final rotation =
        InputImageRotationValue.fromRawValue(description.sensorOrientation) ??
            InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _cameraController;
    if (controller != null && controller.value.isStreamingImages) {
      controller.stopImageStream();
    }
    controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _captureAndSubmit() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        !_isFaceDetected) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Sign in expired. Please sign in again.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Capturing…';
    });

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final picture = await controller.takePicture();

      // Compress the selfie so the JSON payload stays manageable.
      final compressed = await FlutterImageCompress.compressWithFile(
        picture.path,
        quality: 70,
        minWidth: 720,
        minHeight: 720,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      final selfieBytes = compressed ?? await File(picture.path).readAsBytes();

      if (!mounted) return;
      setState(() => _statusMessage = 'Locating you…');

      final position = await _capturePosition();
      if (position == null) {
        _showError(
          'Could not get a GPS lock. Make sure location is enabled and try again.',
        );
        await _restartStream();
        return;
      }

      if (!mounted) return;
      setState(() => _statusMessage = 'Verifying identity…');

      final result = widget.args.mode == TaskScanMode.entrance
          ? await _scanService.entranceScan(
              taskId: widget.args.taskId,
              workerUid: user.uid,
              workerName: widget.args.workerName,
              selfieBytes: Uint8List.fromList(selfieBytes),
              lat: position.latitude,
              lng: position.longitude,
            )
          : await _scanService.exitScan(
              taskId: widget.args.taskId,
              workerUid: user.uid,
              selfieBytes: Uint8List.fromList(selfieBytes),
              lat: position.latitude,
              lng: position.longitude,
            );

      if (!mounted) return;
      setState(() => _lastResult = result);

      switch (result.kind) {
        case WorkerTaskScanKind.passed:
          // Release the front camera *fully* before navigating, so the next
          // screen (evidence log) can open the rear camera without colliding
          // on the platform's "max 1 camera open" limit.
          final controller = _cameraController;
          _cameraController = null;
          if (controller != null) {
            try {
              if (controller.value.isStreamingImages) {
                await controller.stopImageStream();
              }
            } catch (_) {}
            await controller.dispose();
          }
          if (!mounted) return;
          await Navigator.of(context).pushReplacementNamed(
            widget.args.onPassRoute,
            arguments: widget.args.onPassArguments,
          );
          return;
        case WorkerTaskScanKind.outOfRange:
        case WorkerTaskScanKind.failed:
        case WorkerTaskScanKind.locked:
        case WorkerTaskScanKind.error:
          await _restartStream();
          return;
      }
    } catch (e) {
      _showError('Scan failed: $e');
      await _restartStream();
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<Position?> _capturePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _restartStream() async {
    final controller = _cameraController;
    if (controller != null &&
        controller.value.isInitialized &&
        !controller.value.isStreamingImages) {
      try {
        await controller.startImageStream(_processCameraImage);
      } catch (_) {
        // If we can't restart, the user can pop and retry.
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
  }

  String get _title => widget.args.mode == TaskScanMode.entrance
      ? 'Entrance Scan'
      : 'Exit Scan';

  String get _subtitle => widget.args.mode == TaskScanMode.entrance
      ? 'Look at the camera to verify before starting the task.'
      : 'Final identity check before marking the task complete.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deep,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: _title, onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  children: [
                    _Subtitle(text: _subtitle),
                    const SizedBox(height: 16),
                    Expanded(child: _buildCameraView()),
                    const SizedBox(height: 16),
                    _StatusLine(
                      isFaceDetected: _isFaceDetected,
                      result: _lastResult,
                      statusMessage: _statusMessage,
                      isSubmitting: _isSubmitting,
                    ),
                    const SizedBox(height: 16),
                    KbGradientButton(
                      text: _isSubmitting
                          ? 'Verifying…'
                          : (_isFaceDetected
                              ? 'Capture & Verify'
                              : 'Align your face in the frame'),
                      onTap: (_isFaceDetected && !_isSubmitting)
                          ? _captureAndSubmit
                          : null,
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

  Widget _buildCameraView() {
    if (_cameraError != null) {
      return _CameraErrorView(
        message: _cameraError!,
        onRetry: _initializeFrontCamera,
      );
    }
    if (_isInitializing || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          // Soft scrim around an oval guideline.
          IgnorePointer(
            child: CustomPaint(
              painter: _OvalGuidePainter(
                detected: _isFaceDetected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _Header({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 14),
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  final String text;
  const _Subtitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.4,
        color: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final bool isFaceDetected;
  final WorkerTaskScanResult? result;
  final String? statusMessage;
  final bool isSubmitting;

  const _StatusLine({
    required this.isFaceDetected,
    required this.result,
    required this.statusMessage,
    required this.isSubmitting,
  });

  @override
  Widget build(BuildContext context) {
    if (isSubmitting) {
      return _line(
        color: AppColors.orange,
        icon: Icons.autorenew_rounded,
        text: statusMessage ?? 'Verifying…',
      );
    }
    final r = result;
    if (r != null) {
      switch (r.kind) {
        case WorkerTaskScanKind.passed:
          return _line(
            color: AppColors.green,
            icon: Icons.check_circle_rounded,
            text: 'Verified — opening next step…',
          );
        case WorkerTaskScanKind.failed:
          final retries = r.retriesRemaining ?? 0;
          final reason = r.reason == 'liveness_failed'
              ? 'Liveness check failed.'
              : 'Face did not match your verified profile.';
          final tail = retries > 0
              ? ' $retries retry${retries == 1 ? '' : 's'} remaining.'
              : ' Locked out for 5 hours.';
          return _line(
            color: const Color(0xFFFCA5A5),
            icon: Icons.error_rounded,
            text: '$reason$tail',
          );
        case WorkerTaskScanKind.outOfRange:
          final dist = r.distanceMeters?.toStringAsFixed(0) ?? '?';
          final allowed = r.allowedMeters?.toStringAsFixed(0) ?? '50';
          return _line(
            color: const Color(0xFFFCA5A5),
            icon: Icons.gps_off_rounded,
            text: 'Too far: ${dist}m from the task pin (must be within ${allowed}m).',
          );
        case WorkerTaskScanKind.locked:
          return _line(
            color: const Color(0xFFFCA5A5),
            icon: Icons.lock_clock_rounded,
            text: 'You are locked out from accepting tasks.',
          );
        case WorkerTaskScanKind.error:
          return _line(
            color: const Color(0xFFFCA5A5),
            icon: Icons.warning_rounded,
            text: r.errorMessage ?? 'Scan failed. Please try again.',
          );
      }
    }
    return _line(
      color: isFaceDetected ? AppColors.green : Colors.white70,
      icon: isFaceDetected
          ? Icons.face_retouching_natural_rounded
          : Icons.face_rounded,
      text: isFaceDetected
          ? 'Face detected — tap the button to capture.'
          : 'Centre your face in the oval.',
    );
  }

  Widget _line({
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CameraErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded,
                size: 36, color: Colors.white70),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            KbGhostButton(text: 'Retry', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

class _OvalGuidePainter extends CustomPainter {
  final bool detected;
  _OvalGuidePainter({required this.detected});

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.height * 0.7,
    );

    // Punch a hole in the scrim using even-odd fill rule.
    final fullPath = Path()..addRect(Offset.zero & size);
    final ovalPath = Path()..addOval(ovalRect);
    final cutout = Path.combine(PathOperation.difference, fullPath, ovalPath);
    canvas.drawPath(cutout, scrim);

    final guide = Paint()
      ..color = detected
          ? AppColors.green.withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawOval(ovalRect, guide);
  }

  @override
  bool shouldRepaint(covariant _OvalGuidePainter old) =>
      old.detected != detected;
}
