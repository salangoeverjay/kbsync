import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/auth/presentation/screens/face_match_result_screen.dart';

class FaceMatchPrototypeScreen extends StatefulWidget {
  final String referenceImagePath;

  const FaceMatchPrototypeScreen({super.key, required this.referenceImagePath});

  @override
  State<FaceMatchPrototypeScreen> createState() =>
      _FaceMatchPrototypeScreenState();
}

class _FaceMatchPrototypeScreenState extends State<FaceMatchPrototypeScreen>
    with WidgetsBindingObserver {
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
  String? _cameraError;
  bool _didNavigate = false;
  bool _isSubmitting = false;

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
        if (detected && !_isSubmitting) {
          unawaited(_submitFaceMatch());
        }
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

    final format =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Future<void> _submitFaceMatch() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        !_isFaceDetected) {
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again before face match.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      final picture = await controller.takePicture();

      if (!mounted || _didNavigate) return;
      _didNavigate = true;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FaceMatchResultScreen(
            userId: userId,
            userImagePath: picture.path,
            referenceImagePath: widget.referenceImagePath,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _didNavigate = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Face match failed: $e')));
    } finally {
      if (mounted &&
          controller.value.isInitialized &&
          !controller.value.isStreamingImages) {
        await controller.startImageStream(_processCameraImage);
      }
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: Center(child: _buildCameraView())),
    );
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

    if (_isInitializing ||
        controller == null ||
        !controller.value.isInitialized) {
      return const SizedBox(
        width: 64,
        height: 64,
        child: CircularProgressIndicator(
          strokeWidth: 2.8,
          color: AppColors.orange,
        ),
      );
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const ColoredBox(color: Color(0xFFE9D9E2));
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: CameraPreview(controller),
      ),
    );
  }
}
