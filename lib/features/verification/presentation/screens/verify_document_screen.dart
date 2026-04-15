import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/verification/data/philippine_id_verification_service.dart';
import 'package:kbsync/features/verification/presentation/screens/verification_review_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class VerifyDocumentScreen extends StatefulWidget {
  final String documentType;

  const VerifyDocumentScreen({super.key, required this.documentType});

  @override
  State<VerifyDocumentScreen> createState() => _VerifyDocumentScreenState();
}

class _VerifyDocumentScreenState extends State<VerifyDocumentScreen> {
  static const double _idCardAspectRatio = 1.586; // ISO ID-1 card ratio
  CameraController? _cameraController;
  XFile? _capturedImage;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isVerifying = false;
  bool _isAutoCapturing = false;
  String? _cameraError;
  final _verificationService = PhilippineIdVerificationService();
  Timer? _autoScanTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _stopAutoScan();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _cameraError = null;
    });

    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (!mounted) return;
        setState(() {
          _cameraError = 'Camera permission is required.';
          _isInitializing = false;
        });
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameraError = 'No camera found on this device.';
          _isInitializing = false;
        });
        return;
      }

      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await _cameraController?.dispose();

      setState(() {
        _cameraController = controller;
        _isInitializing = false;
      });
      _startAutoScan();
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = _cameraErrorMessage(error.code);
        _isInitializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Unable to start in-app camera.';
        _isInitializing = false;
      });
    }
  }

  String _cameraErrorMessage(String code) {
    switch (code) {
      case 'CameraAccessDenied':
      case 'cameraPermission':
        return 'Camera permission was denied.';
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Enable camera permission from settings.';
      case 'CameraAccessRestricted':
        return 'Camera access is restricted on this device.';
      default:
        return 'Unable to open in-app camera ($code).';
    }
  }

  Future<void> _captureDocument() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing ||
        _isVerifying) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      setState(() => _capturedImage = file);
      await _verifyCapturedDocument(file, silentOnInvalid: false);
    } on CameraException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Capture failed: ${_cameraErrorMessage(error.code)}'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<bool> _verifyCapturedDocument(
    XFile file, {
    required bool silentOnInvalid,
  }) async {
    setState(() => _isVerifying = true);
    try {
      final result = await _verificationService.verifyDocument(
        documentType: widget.documentType,
        imagePath: file.path,
      );
      if (!mounted) return false;

      if (!result.isValid) {
        if (!silentOnInvalid) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result.message)));
        }
        return false;
      }

      _stopAutoScan();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerificationReviewScreen(
            documentType: widget.documentType,
            details: result.details,
            onRetake: () {
              if (!mounted) return;
              setState(() => _capturedImage = null);
              _startAutoScan();
            },
          ),
        ),
      );
      return true;
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _startAutoScan() {
    _stopAutoScan();
    _autoScanTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _attemptAutoCapture();
    });
  }

  void _stopAutoScan() {
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
  }

  Future<void> _attemptAutoCapture() async {
    if (!mounted ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing ||
        _isVerifying ||
        _isAutoCapturing) {
      return;
    }

    _isAutoCapturing = true;
    setState(() => _isCapturing = true);
    try {
      final file = await _cameraController!.takePicture();
      if (!mounted) return;

      final success = await _verifyCapturedDocument(
        file,
        silentOnInvalid: true,
      );

      if (!success) {
        try {
          await File(file.path).delete();
        } catch (_) {
          // Ignore temporary file deletion issues.
        }
      } else if (mounted) {
        setState(() => _capturedImage = file);
      }
    } catch (_) {
      // Silent on auto mode. Manual capture still reports errors.
    } finally {
      _isAutoCapturing = false;
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Widget _buildCameraArea() {
    if (_capturedImage != null) {
      return Image.file(
        File(_capturedImage!.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.orange),
      );
    }

    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _initializeCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                ),
                child: const Text('Try again'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: openAppSettings,
                child: const Text('Open app settings'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.orange),
      );
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);

    // Keep camera proportions accurate and crop overflow instead of stretching.
    final previewAspectRatio = previewSize.height / previewSize.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerAspectRatio =
            constraints.maxWidth / constraints.maxHeight;
        double scale = previewAspectRatio / containerAspectRatio;
        if (scale < 1) scale = 1 / scale;

        return ClipRect(
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: AspectRatio(
                aspectRatio: previewAspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.deep),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Verify ${widget.documentType}',
                      style: const TextStyle(
                        color: AppColors.deep,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                children: [
                  Expanded(child: _ScanStepBar(active: true)),
                  SizedBox(width: 4),
                  Expanded(child: _ScanStepBar(active: false)),
                  SizedBox(width: 4),
                  Expanded(child: _ScanStepBar(active: false)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AspectRatio(
                aspectRatio: _idCardAspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.black),
                      _buildCameraArea(),
                      const IDOverlay(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Center(
              child: GestureDetector(
                onTap: _captureDocument,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0x1AFF5A00),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: _isCapturing || _isVerifying
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.orange,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          color: AppColors.orange,
                          size: 32,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'Scan Document',
                style: TextStyle(
                  color: AppColors.plum,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _isVerifying
                      ? 'Verifying your ${widget.documentType.toLowerCase()}...'
                      : 'Align your ID within the frame then tap capture.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            if (_capturedImage != null)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _capturedImage = null),
                  child: const Text('Retake photo'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanStepBar extends StatelessWidget {
  final bool active;

  const _ScanStepBar({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 7,
      decoration: BoxDecoration(
        color: active ? AppColors.orange : const Color(0x40FF5A00),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class IDOverlay extends StatelessWidget {
  const IDOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: const [
            Align(alignment: Alignment.topLeft, child: _IDCorner()),
            Align(
              alignment: Alignment.topRight,
              child: _IDCorner(isRight: true),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: _IDCorner(isBottom: true),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: _IDCorner(isRight: true, isBottom: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _IDCorner extends StatelessWidget {
  final bool isRight;
  final bool isBottom;

  const _IDCorner({this.isRight = false, this.isBottom = false});

  @override
  Widget build(BuildContext context) {
    const stroke = 6.0;
    const radius = 18.0;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        border: Border(
          top: isBottom
              ? BorderSide.none
              : const BorderSide(color: AppColors.orange, width: stroke),
          bottom: isBottom
              ? const BorderSide(color: AppColors.orange, width: stroke)
              : BorderSide.none,
          left: isRight
              ? BorderSide.none
              : const BorderSide(color: AppColors.orange, width: stroke),
          right: isRight
              ? const BorderSide(color: AppColors.orange, width: stroke)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: !isRight && !isBottom
              ? const Radius.circular(radius)
              : Radius.zero,
          topRight: isRight && !isBottom
              ? const Radius.circular(radius)
              : Radius.zero,
          bottomLeft: !isRight && isBottom
              ? const Radius.circular(radius)
              : Radius.zero,
          bottomRight: isRight && isBottom
              ? const Radius.circular(radius)
              : Radius.zero,
        ),
      ),
    );
  }
}
