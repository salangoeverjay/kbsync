import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/auth/data/verification_api_service.dart';
import 'package:kbsync/features/auth/presentation/screens/review_details_prototype_screen.dart';

class DocumentScanPrototypeScreen extends StatefulWidget {
  final String documentLabel;

  const DocumentScanPrototypeScreen({
    super.key,
    required this.documentLabel,
  });

  @override
  State<DocumentScanPrototypeScreen> createState() => _DocumentScanPrototypeScreenState();
}

class _DocumentScanPrototypeScreenState extends State<DocumentScanPrototypeScreen>
    with WidgetsBindingObserver {
  final VerificationApiService _verificationApiService = VerificationApiService();

  CameraController? _cameraController;
  bool _isInitializingCamera = true;
  bool _isCapturing = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      controller.dispose();
      _cameraController = null;
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;

    setState(() {
      _isInitializingCamera = true;
      _cameraError = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCameraFound', 'No camera is available on this device.');
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final newController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await newController.initialize();

      if (!mounted) {
        await newController.dispose();
        return;
      }

      final oldController = _cameraController;
      setState(() {
        _cameraController = newController;
        _isInitializingCamera = false;
      });
      await oldController?.dispose();
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraController = null;
        _isInitializingCamera = false;
        _cameraError = _cameraErrorMessage(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraController = null;
        _isInitializingCamera = false;
        _cameraError = 'Unable to start the camera. Please try again.';
      });
    }
  }

  String _cameraErrorMessage(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Camera permission is denied. Please allow it in settings.';
      case 'CameraAccessRestricted':
        return 'Camera access is restricted on this device.';
      default:
        return e.description ?? 'Unable to start the camera. Please try again.';
    }
  }

  Future<void> _captureId() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again before starting verification.')),
      );
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final picture = await controller.takePicture();

      final verificationResult = await _verificationApiService.verifyDocument(
        userId: userId,
        documentLabel: widget.documentLabel,
        frontImagePath: picture.path,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReviewDetailsPrototypeScreen(
            documentLabel: widget.documentLabel,
            referenceImagePath: picture.path,
            requestId: verificationResult.requestId,
            status: verificationResult.status,
            fullName: verificationResult.fullName,
            dateOfBirth: verificationResult.dateOfBirth,
            sex: verificationResult.sex,
            idNumber: verificationResult.idNumber,
          ),
        ),
      );
    } on CameraException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.description ?? 'Failed to capture image. Please try again.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to verify document: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 55, 0),
              child: Row(
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Verify ${widget.documentLabel}',
                      style: const TextStyle(
                        color: AppColors.deep,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 1),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: _ProgressBar(),
            ),
            _DocumentCaptureFrame(
              controller: _cameraController,
              isInitializingCamera: _isInitializingCamera,
              cameraError: _cameraError,
            ),
            const SizedBox(height: 73),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0x1AFF5A00),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_outlined,
                size: 32,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(height: 13),
            const Text(
              'Scan Document',
              style: TextStyle(
                color: AppColors.plum,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Align your ID within the frame and tap capture.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.ink.withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 31),
              child: _CaptureIdButton(
                isLoading: _isCapturing,
                enabled:
                    !_isInitializingCamera &&
                    _cameraError == null &&
                    _cameraController != null &&
                    _cameraController!.value.isInitialized,
                onTap: _captureId,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureIdButton extends StatelessWidget {
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  const _CaptureIdButton({
    required this.isLoading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !isLoading;
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: double.infinity,
        height: 51,
        decoration: BoxDecoration(
          color: canTap ? AppColors.orange : AppColors.orange.withValues(alpha: 0.5),
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
          onTap: canTap ? onTap : null,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Capture ID',
                    style: TextStyle(
                      color: Color(0xFFFFFDFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 24 / 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: const [
          _Segment(color: AppColors.orange),
          SizedBox(width: 3),
          _Segment(color: Color(0x40FF5A00)),
          SizedBox(width: 3),
          _Segment(color: Color(0x40FF5A00)),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final Color color;

  const _Segment({required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Align(
        alignment: Alignment.center,
        child: Container(
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _DocumentCaptureFrame extends StatelessWidget {
  final CameraController? controller;
  final bool isInitializingCamera;
  final String? cameraError;

  const _DocumentCaptureFrame({
    required this.controller,
    required this.isInitializingCamera,
    required this.cameraError,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 262,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: _CameraPreviewSurface(
              controller: controller,
              isInitializingCamera: isInitializingCamera,
              cameraError: cameraError,
            ),
          ),
          const Positioned(
            left: 21,
            top: 12,
            child: _CornerMarker(corner: _Corner.topLeft),
          ),
          const Positioned(
            right: 22,
            top: 12,
            child: _CornerMarker(corner: _Corner.topRight),
          ),
          const Positioned(
            left: 21,
            bottom: 12,
            child: _CornerMarker(corner: _Corner.bottomLeft),
          ),
          const Positioned(
            right: 22,
            bottom: 12,
            child: _CornerMarker(corner: _Corner.bottomRight),
          ),
        ],
      ),
    );
  }
}

class _CameraPreviewSurface extends StatelessWidget {
  final CameraController? controller;
  final bool isInitializingCamera;
  final String? cameraError;

  const _CameraPreviewSurface({
    required this.controller,
    required this.isInitializingCamera,
    required this.cameraError,
  });

  @override
  Widget build(BuildContext context) {
    if (cameraError != null) {
      return Container(
        color: Colors.black12,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          cameraError!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.deep,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (isInitializingCamera || controller == null || !controller!.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black12,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.orange,
            ),
          ),
        ),
      );
    }

    final previewSize = controller!.value.previewSize;
    if (previewSize == null) {
      return const ColoredBox(color: Colors.black12);
    }

    return ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewSize.height,
              height: previewSize.width,
              child: CameraPreview(controller!),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CornerMarker extends StatelessWidget {
  final _Corner corner;

  const _CornerMarker({
    required this.corner,
  });

  @override
  Widget build(BuildContext context) {
    Border border;
    BorderRadius borderRadius;

    switch (corner) {
      case _Corner.topLeft:
        border = const Border(
          top: BorderSide(color: AppColors.orange, width: 6),
          left: BorderSide(color: AppColors.orange, width: 6),
        );
        borderRadius = const BorderRadius.only(topLeft: Radius.circular(28));
        break;
      case _Corner.topRight:
        border = const Border(
          top: BorderSide(color: AppColors.orange, width: 6),
          right: BorderSide(color: AppColors.orange, width: 6),
        );
        borderRadius = const BorderRadius.only(topRight: Radius.circular(28));
        break;
      case _Corner.bottomLeft:
        border = const Border(
          bottom: BorderSide(color: AppColors.orange, width: 6),
          left: BorderSide(color: AppColors.orange, width: 6),
        );
        borderRadius = const BorderRadius.only(bottomLeft: Radius.circular(28));
        break;
      case _Corner.bottomRight:
        border = const Border(
          bottom: BorderSide(color: AppColors.orange, width: 6),
          right: BorderSide(color: AppColors.orange, width: 6),
        );
        borderRadius = const BorderRadius.only(bottomRight: Radius.circular(28));
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: border,
        borderRadius: borderRadius,
      ),
    );
  }
}
