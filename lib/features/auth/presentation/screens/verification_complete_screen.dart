import 'package:camera/camera.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show WriteBuffer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/auth/data/verification_api_service.dart';

class VerificationCompleteScreen extends StatefulWidget {
  final String title;
  final String instructionTitle;
  final String instructionSubtitle;
  final String notDetectedLabel;
  final String detectedLabel;
  final VoidCallback? onVerified;
  final bool requiresPassiveLiveness;
  final String? passiveLivenessUserId;
  final int faceLivenessScoreDeclineThreshold;
  final bool rotateImageForLiveness;
  final ValueChanged<String>? onPassiveLivenessApproved;

  const VerificationCompleteScreen({
    super.key,
    this.title = 'Verify Identity',
    this.instructionTitle = 'Position your face within the frame.',
    this.instructionSubtitle =
        'Make sure you are in a well-lit area and your face is\nclearly visible.',
    this.notDetectedLabel = 'Face not detected',
    this.detectedLabel = 'Continue',
    this.onVerified,
    this.requiresPassiveLiveness = false,
    this.passiveLivenessUserId,
    this.faceLivenessScoreDeclineThreshold = 70,
    this.rotateImageForLiveness = true,
    this.onPassiveLivenessApproved,
  });

  @override
  State<VerificationCompleteScreen> createState() =>
      _VerificationCompleteScreenState();
}

class _VerificationCompleteScreenState extends State<VerificationCompleteScreen>
    with WidgetsBindingObserver {
  final VerificationApiService _verificationApiService = VerificationApiService();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: false,
      enableLandmarks: false,
    ),
  );

  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _isFaceDetected = false;
  bool _isProcessingFrame = false;
  bool _isSubmittingLiveness = false;
  String? _cameraError;

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

  Future<void> _initializeFrontCamera() async {
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
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final newController = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await newController.initialize();
      await newController.startImageStream(_processCameraImage);

      if (!mounted) {
        await newController.dispose();
        return;
      }

      final oldController = _cameraController;
      setState(() {
        _cameraController = newController;
        _isInitializing = false;
      });
      await oldController?.dispose();
    } on CameraException catch (e) {
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
    if (_cameraController == null) return;

    _isProcessingFrame = true;
    try {
      final inputImage = _toInputImage(image, _cameraController!.description);
      final faces = await _faceDetector.processImage(inputImage);
      final detected = faces.isNotEmpty;
      if (mounted && detected != _isFaceDetected) {
        setState(() => _isFaceDetected = detected);
      }
    } catch (_) {
      // Ignore single-frame processing failures.
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

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
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

  @override
  Widget build(BuildContext context) {
    final buttonText = _isSubmittingLiveness
        ? 'Verifying...'
        : _isFaceDetected
            ? widget.detectedLabel
            : widget.notDetectedLabel;
    final buttonColor =
        _isFaceDetected ? AppColors.orange : const Color(0xFF8D6E80);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.deep,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.deep,
                      fontSize: 38 / 1.73,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const _ProgressBar(),
              const SizedBox(height: 16),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 334,
                        height: 334,
                        child: _buildCameraView(),
                      ),
                    ),
                    const SizedBox(
                      width: 212,
                      height: 274,
                      child: CustomPaint(
                        painter: _DashedOvalPainter(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  widget.instructionTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.plum,
                    fontSize: 38 / 1.73,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  widget.instructionSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              _ActionButton(
                text: buttonText,
                color: buttonColor,
                onTap: (_isFaceDetected && !_isSubmittingLiveness)
                    ? _onContinuePressed
                    : null,
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onContinuePressed() async {
    if (!widget.requiresPassiveLiveness) {
      _completeFlow();
      return;
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    setState(() => _isSubmittingLiveness = true);

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      final picture = await controller.takePicture();
      final userId = widget.passiveLivenessUserId ?? FirebaseAuth.instance.currentUser?.uid;
      if (userId == null || userId.trim().isEmpty) {
        throw Exception('No authenticated user found for liveness validation.');
      }

      final result = await _verificationApiService.verifyPassiveLiveness(
        userId: userId,
        userImagePath: picture.path,
        faceLivenessScoreDeclineThreshold: widget.faceLivenessScoreDeclineThreshold,
        rotateImage: widget.rotateImageForLiveness,
      );

      if (!mounted) return;

      if (result.isApproved) {
        if (widget.onPassiveLivenessApproved != null) {
          widget.onPassiveLivenessApproved!(picture.path);
          return;
        }
        _completeFlow();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Passive liveness not approved (status: ${result.status}). Please try again.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passive liveness failed: $e')),
      );
    } finally {
      if (controller.value.isInitialized && !controller.value.isStreamingImages) {
        await controller.startImageStream(_processCameraImage);
      }
      if (mounted) {
        setState(() => _isSubmittingLiveness = false);
      }
    }
  }

  void _completeFlow() {
    if (widget.onVerified != null) {
      widget.onVerified!.call();
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildCameraView() {
    final controller = _cameraController;
    if (_cameraError != null) {
      return Container(
        color: const Color(0xFFE9D9E2),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(
          _cameraError!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.plum,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_isInitializing || controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Color(0xFFE9D9E2),
        child: Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.8,
              color: AppColors.orange,
            ),
          ),
        ),
      );
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const ColoredBox(color: Color(0xFFE9D9E2));
    }

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _Segment(active: true),
        SizedBox(width: 8),
        _Segment(active: true),
        SizedBox(width: 8),
        _Segment(active: true),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  final bool active;

  const _Segment({required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: active ? AppColors.orange : const Color(0xFFD8BECB),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: 56,
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
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedOvalPainter extends CustomPainter {
  const _DashedOvalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()..addOval(rect);

    const dashLength = 13.0;
    const gapLength = 9.0;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
