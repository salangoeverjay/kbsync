import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/widgets/kb_bottom_nav.dart';
import 'package:kbsync/core/widgets/kb_buttons.dart';
import 'package:kbsync/features/auth/data/firebase_auth_service.dart';
import 'package:kbsync/features/resident/data/resident_task_service.dart';
import 'package:kbsync/features/resident/data/resident_location_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:kbsync/features/wallet/data/paymongo_service.dart';
import 'package:kbsync/features/wallet/presentation/widgets/merchant_qr_sheet.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final ResidentTaskService _taskService = ResidentTaskService();
  final PaymongoService _paymongoService = PaymongoService();
  final ImagePicker _imagePicker = ImagePicker();
  final ResidentLocationService _locationService = ResidentLocationService();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _groceryItemsController = TextEditingController();
  final TextEditingController _groceryBudgetController =
      TextEditingController();
  String? _userRole;
  String _service = 'Cleaning';
  bool _initializedFromArgs = false;
  String _complexity = 'Moderate';
  String _mode = 'rush';
  final Set<String> _cleaningAreas = {'Living Room'};
  final Set<String> _groceryStops = {'Palengke'};
  bool _laundryByKg = true;
  int _laundryKg = 3;
  int _laundryClothes = 12;
  XFile? _referencePhoto;
  bool _isUploadingPhoto = false;
  bool _isPublishing = false;

  static const Map<String, int> _serviceBasePrice = {
    'Cleaning': 180,
    'Laundry': 160,
    'Grocery': 140,
    'Dishes': 150,
  };
  static const int _additionalAreaFee = 35;
  static const int _additionalGroceryStopFee = 20;
  static const int _laundryIncludedKg = 3;
  static const int _laundryIncludedClothes = 12;
  static const int _laundryExtraPerKg = 25;
  static const int _laundryExtraPerClothes = 6;
  static const Map<String, int> _complexityFee = {
    'Light': 0,
    'Moderate': 30,
    'Heavy': 60,
  };
  static const int _rushFee = 50;

  static const _services = [
    (key: 'Laundry', emoji: '🧺'),
    (key: 'Grocery', emoji: '🛒'),
    (key: 'Cleaning', emoji: '🧹'),
    (key: 'Dishes', emoji: '🍽️'),
  ];

  static const _allAreas = [
    'Bathroom',
    'Bedroom',
    'Living Room',
    'Kitchen',
    'Garden',
    'Garage',
  ];

  static const _groceryLocations = [
    'Palengke',
    'Mall',
    'Supermarket',
    'Convenience Store',
    'Pharmacy',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedFromArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['service'] is String) {
        final svc = (args['service'] as String).trim();
        final normalized = _normalizeIncomingService(svc);
        if (normalized.isNotEmpty && normalized != _service) {
          setState(() => _service = normalized);
        }
      } else if (args is String) {
        final normalized = _normalizeIncomingService(args);
        if (normalized.isNotEmpty && normalized != _service) {
          setState(() => _service = normalized);
        }
      }
      _initializedFromArgs = true;
    }
  }

  Future<void> _loadUserRole() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final verificationState = await _authService.getVerificationState(
        uid: userId,
      );
      if (!mounted) return;
      setState(() {
        _userRole = verificationState?.role;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _notesController.dispose();
    _groceryItemsController.dispose();
    _groceryBudgetController.dispose();
    super.dispose();
  }

  Future<String> _resolveUserRole() async {
    final cached = _userRole;
    if (cached != null && cached.isNotEmpty) return cached;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return 'resident';

    try {
      final verificationState = await _authService.getVerificationState(
        uid: userId,
      );
      final role = verificationState?.role?.trim().toLowerCase();
      if (role != null && role.isNotEmpty) {
        if (mounted) {
          setState(() {
            _userRole = role;
          });
        }
        return role;
      }
    } catch (_) {}

    return 'resident';
  }

  Future<void> _onNavTap(KbNavTab tab) async {
    if (tab == KbNavTab.tasks) return;

    final role = await _resolveUserRole();
    if (!mounted) return;

    if (tab == KbNavTab.home) {
      final homeRoute = role == 'resident'
          ? AppRoutes.residentDashboard
          : AppRoutes.workerDashboard;
      Navigator.of(context).pushReplacementNamed(homeRoute);
    } else if (tab == KbNavTab.wallet) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.wallet);
    } else if (tab == KbNavTab.profile) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.profile);
    }
  }

  int get _selectedAreaCount =>
      _cleaningAreas.isEmpty ? 1 : _cleaningAreas.length;

  List<String> get _selectedDetails {
    switch (_service) {
      case 'Laundry':
        return [_laundryByKg ? '$_laundryKg kg' : '$_laundryClothes clothes'];
      case 'Grocery':
        return _groceryStops.toList(growable: false);
      case 'Dishes':
        return const ['General'];
      case 'Cleaning':
      default:
        return _cleaningAreas.toList(growable: false);
    }
  }

  List<String> get _groceryItems {
    final raw = _groceryItemsController.text;
    return raw
        .split(RegExp(r'[\n,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  double? get _groceryBudget {
    final raw = _groceryBudgetController.text.trim().replaceAll(',', '');
    return double.tryParse(raw);
  }

  bool get _requiresMerchantQrPayment {
    if (_service != 'Grocery') return false;
    final budget = _groceryBudget;
    return budget != null && budget > 200;
  }

  int get _serviceDetailFee {
    switch (_service) {
      case 'Laundry':
        if (_laundryByKg) {
          final extraKg = (_laundryKg - _laundryIncludedKg).clamp(0, 1000);
          return extraKg * _laundryExtraPerKg;
        }
        final extraClothes = (_laundryClothes - _laundryIncludedClothes).clamp(
          0,
          10000,
        );
        return extraClothes * _laundryExtraPerClothes;
      case 'Grocery':
        final extraStops = (_groceryStops.length - 1).clamp(0, 1000);
        return extraStops * _additionalGroceryStopFee;
      case 'Dishes':
        return _complexityFee[_complexity] ?? 0;
      case 'Cleaning':
        final complexityFee = _complexityFee[_complexity] ?? 0;
        final extraAreas = (_selectedAreaCount - 1).clamp(0, 1000);
        return complexityFee + (extraAreas * _additionalAreaFee);
      default:
        return 0;
    }
  }

  int get _totalAmount {
    final base = _serviceBasePrice[_service] ?? 180;
    final detailFee = _serviceDetailFee;
    final modeFee = _mode == 'rush' ? _rushFee : 0;
    return base + detailFee + modeFee;
  }

  String get _totalLabel => _formatPeso(_totalAmount);

  String _formatPeso(int amount) => '₱$amount';

  String _normalizeIncomingService(String s) {
    final v = s.trim().toLowerCase();
    if (v == 'pabili' || v == 'grocery') return 'Grocery';
    if (v == 'laundry') return 'Laundry';
    if (v == 'dishes') return 'Dishes';
    if (v == 'cleaning') return 'Cleaning';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sticky total + publish bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Total Payment',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.ink.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      _totalLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        color: AppColors.plum,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                KbGradientButton(
                  text: _isPublishing ? 'Publishing...' : 'Publish Request',
                  height: 52,
                  onTap: _isPublishing ? null : _publishTask,
                ),
              ],
            ),
          ),
          KbBottomNav(active: KbNavTab.tasks, onTap: (tab) => _onNavTap(tab)),
        ],
      ),
      body: Column(
        children: [
          // Plum header
          Container(
            color: AppColors.plum,
            child: SafeArea(
              bottom: false,
              child: _Header(onBack: () => Navigator.of(context).pop()),
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What do you need help with?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.6,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _serviceSection(),
                  const SizedBox(height: 18),
                  _groceryBudgetSection(),
                  const SizedBox(height: 18),
                  _groceryItemsSection(),
                  const SizedBox(height: 18),
                  _notesSection(),
                  const SizedBox(height: 18),
                  _referencePhotoSection(),
                  const SizedBox(height: 18),
                  _serviceDetailsSection(),
                  const SizedBox(height: 18),
                  if (_service == 'Dishes' || _service == 'Cleaning') ...[
                    _complexitySection(),
                    const SizedBox(height: 18),
                  ],
                  _modeSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _publishTask() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again to publish a task.'),
        ),
      );
      return;
    }

    if (_service == 'Grocery') {
      final hasList = _groceryItems.isNotEmpty;
      final budget = _groceryBudget;
      final hasBudget = budget != null && budget > 0;
      if (!hasList && !hasBudget) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add a buy list or grocery budget before publishing.',
            ),
          ),
        );
        return;
      }
    }

    if (_service != 'Grocery' && _referencePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a reference photo for the worker before publishing.',
          ),
        ),
      );
      return;
    }

    final ownerName = await _authService.getCurrentUserFullName();
    if (!mounted) return;

    setState(() => _isPublishing = true);
    try {
      setState(() => _isUploadingPhoto = true);
      final referencePhotoUrl = await _uploadReferencePhoto(currentUser.uid);
      // Capture current resident location and lock it to the task
      LatLng userLocation;
      try {
        userLocation = await _locationService.getCurrentLocation();
      } catch (_) {
        userLocation = ResidentLocationService.fallbackLocation;
      }
      if (!mounted) return;

      final notes = _notesController.text.trim();
      final ref = await _taskService.publishTask(
        uid: currentUser.uid,
        ownerName: ownerName ?? 'User',
        service: _service,
        areas: _selectedDetails,
        icon: _serviceIcon(_service),
        complexity: (_service == 'Dishes' || _service == 'Cleaning')
            ? _complexity
            : null,
        mode: _mode,
        total: _totalLabel,
        groceryItems: _service == 'Grocery' ? _groceryItems : const <String>[],
        groceryBudget: _service == 'Grocery' ? _groceryBudget : null,
        paymentProtocol: _requiresMerchantQrPayment
            ? 'merchant_qr'
            : 'cash_or_wallet',
        merchantQrPayload: _requiresMerchantQrPayment
            ? _buildMerchantQrPayload(
                ownerId: currentUser.uid,
                ownerName: ownerName ?? 'User',
              )
            : null,
        referencePhotoUrl: referencePhotoUrl,
        notes: notes.isEmpty ? null : notes,
        latitude: userLocation.latitude,
        longitude: userLocation.longitude,
      );

      if (!mounted) return;

      if (_requiresMerchantQrPayment) {
        await _runMerchantQrCheckout(taskId: ref.id);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request published successfully.')),
      );
      Navigator.of(context).pushReplacementNamed(AppRoutes.residentDashboard);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to publish task: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _pickReferencePhoto(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() => _referencePhoto = picked);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pick photo: $error')));
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickReferencePhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickReferencePhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Spark plan blocks Firebase Storage, so the reference photo is compressed
  // to JPEG and embedded as a data: URI inside the task doc. The worker UI
  // detects the `data:image/...` prefix and decodes via Image.memory.
  // Hard cap: ~700 KB raw -> ~933 KB encoded, leaving headroom under the
  // 1 MiB Firestore doc limit.
  static const int _maxRefPhotoRawBytes = 700 * 1024;

  Future<String?> _uploadReferencePhoto(String ownerUid) async {
    final photo = _referencePhoto;
    if (photo == null) return null;

    Uint8List? bytes;
    for (final quality in const [72, 60, 50, 40, 30]) {
      final attempt = await FlutterImageCompress.compressWithFile(
        photo.path,
        quality: quality,
        minWidth: 1280,
        minHeight: 1280,
        format: CompressFormat.jpeg,
      );
      if (attempt == null) continue;
      bytes = attempt;
      if (attempt.lengthInBytes <= _maxRefPhotoRawBytes) break;
    }
    bytes ??= await File(photo.path).readAsBytes();
    if (bytes.lengthInBytes > _maxRefPhotoRawBytes) {
      throw StateError(
        'Reference photo still too large after compression: '
        '${bytes.lengthInBytes} bytes (max $_maxRefPhotoRawBytes).',
      );
    }

    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  Future<void> _runMerchantQrCheckout({required String taskId}) async {
    final budget = _groceryBudget;
    if (budget == null) return;

    try {
      final qr = await _paymongoService.createTaskQrPayment(
        amountPesos: budget,
        taskId: taskId,
      );
      if (!mounted) return;

      final taskStream = FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .snapshots();

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (sheetCtx) => MerchantQrSheet(
          formattedAmount: '₱${budget.toStringAsFixed(2)}',
          taskTitle: 'Grocery – ${_groceryStops.join(', ')}',
          qrCodeUrl: qr.qrCodeUrl,
          taskStream: taskStream,
          onClose: () => Navigator.of(sheetCtx).pop(),
          onFunded: () {
            Navigator.of(sheetCtx).pop();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment received. Task is now funded.'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.plum,
              ),
            );
            Navigator.of(
              context,
            ).pushReplacementNamed(AppRoutes.residentDashboard);
          },
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start merchant payment: $err')),
      );
    }
  }

  String _serviceIcon(String service) {
    return switch (service) {
      'Laundry' => '🧺',
      'Grocery' => '🛒',
      'Cleaning' => '🧹',
      'Dishes' => '🍽️',
      _ => '🧹',
    };
  }

  String _buildMerchantQrPayload({
    required String ownerId,
    required String ownerName,
  }) {
    final budget = _groceryBudget?.toStringAsFixed(2) ?? '0.00';
    final locations = _groceryStops.join(', ');
    return 'KBSYNC|MERCHANT_QR|owner:$ownerId|name:$ownerName|budget:$budget|locations:$locations';
  }

  Widget _serviceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('SERVICE TYPE'),
        const SizedBox(height: 10),
        Row(
          children: _services.map((s) {
            final on = _service == s.key;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _service = s.key),
                child: Container(
                  margin: EdgeInsets.only(
                    right: s.key == _services.last.key ? 0 : 8,
                  ),
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: on ? AppColors.grad : null,
                    color: on ? null : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: on
                            ? AppColors.plum.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.06),
                        blurRadius: on ? 20 : 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(
                        s.key,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: on ? Colors.white : AppColors.ink,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _notesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('NOTES'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _notesController,
            decoration: InputDecoration.collapsed(
              hintText: 'Add specific details...',
              hintStyle: TextStyle(
                fontFamily: 'PublicSans',
                fontSize: 13,
                color: AppColors.plum.withValues(alpha: 0.3),
              ),
            ),
            style: const TextStyle(fontSize: 13, color: AppColors.plum),
          ),
        ),
      ],
    );
  }

  Widget _referencePhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('REFERENCE PHOTO'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_referencePhoto != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(_referencePhoto!.path),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 90,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.orangeLt.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _service == 'Grocery'
                        ? 'Optional photo'
                        : 'Required for $_service tasks',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showPhotoSourceSheet,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                      label: Text(
                        _referencePhoto == null ? 'Add Photo' : 'Replace Photo',
                      ),
                    ),
                  ),
                  if (_referencePhoto != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => setState(() => _referencePhoto = null),
                      child: const Text('Remove'),
                    ),
                  ],
                ],
              ),
              if (_isUploadingPhoto)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _groceryItemsSection() {
    if (_service != 'Grocery') return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('WHAT TO BUY'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _groceryItemsController,
            maxLines: 4,
            decoration: InputDecoration.collapsed(
              hintText: 'Example: 1 sack rice, 2 eggs, 1 liter milk',
              hintStyle: TextStyle(
                fontFamily: 'PublicSans',
                fontSize: 13,
                color: AppColors.plum.withValues(alpha: 0.3),
              ),
            ),
            style: const TextStyle(fontSize: 13, color: AppColors.plum),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Separate items with commas or new lines.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.ink.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Widget _groceryBudgetSection() {
    if (_service != 'Grocery') return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('GROCERY BUDGET'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _groceryBudgetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration.collapsed(
              hintText: 'Example: 500',
              hintStyle: TextStyle(
                fontFamily: 'PublicSans',
                fontSize: 13,
                color: AppColors.plum.withValues(alpha: 0.3),
              ),
            ),
            style: const TextStyle(fontSize: 13, color: AppColors.plum),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'If no exact items are listed, the worker will shop within this budget.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.ink.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Widget _serviceDetailsSection() {
    switch (_service) {
      case 'Laundry':
        return _laundryDetailsSection();
      case 'Grocery':
        return _grocerySection();
      case 'Dishes':
        return const SizedBox.shrink();
      case 'Cleaning':
      default:
        return _cleaningAreasSection();
    }
  }

  Widget _cleaningAreasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('SELECT AREAS'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allAreas.map((a) {
            final on = _cleaningAreas.contains(a);
            return GestureDetector(
              onTap: () => setState(() {
                if (on && _cleaningAreas.length > 1) {
                  _cleaningAreas.remove(a);
                } else if (!on) {
                  _cleaningAreas.add(a);
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: on ? AppColors.orangeLt : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: on ? AppColors.orange : const Color(0x80BEC8D1),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  a,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: on ? AppColors.orange : AppColors.ink,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _grocerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('SHOPPING LOCATION'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _groceryLocations.map((location) {
            final on = _groceryStops.contains(location);
            return GestureDetector(
              onTap: () => setState(() {
                if (on && _groceryStops.length > 1) {
                  _groceryStops.remove(location);
                } else if (!on) {
                  _groceryStops.add(location);
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: on ? AppColors.orangeLt : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: on ? AppColors.orange : const Color(0x80BEC8D1),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  location,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: on ? AppColors.orange : AppColors.ink,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _laundryDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('LAUNDRY SIZE'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _laundryByKg = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _laundryByKg ? AppColors.orangeLt : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _laundryByKg
                          ? AppColors.orange
                          : const Color(0x80BEC8D1),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'By Kg',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _laundryByKg ? AppColors.orange : AppColors.ink,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _laundryByKg = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !_laundryByKg ? AppColors.orangeLt : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: !_laundryByKg
                          ? AppColors.orange
                          : const Color(0x80BEC8D1),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'By Clothes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: !_laundryByKg ? AppColors.orange : AppColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _CounterCard(
          label: _laundryByKg ? 'Kilograms' : 'Number of Clothes',
          suffix: _laundryByKg ? 'kg' : 'pcs',
          value: _laundryByKg ? _laundryKg : _laundryClothes,
          min: 1,
          onChanged: (next) => setState(() {
            if (_laundryByKg) {
              _laundryKg = next;
            } else {
              _laundryClothes = next;
            }
          }),
        ),
      ],
    );
  }

  Widget _complexitySection() {
    const complexities = ['Light', 'Moderate', 'Heavy'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('COMPLEXITY'),
        const SizedBox(height: 8),
        Row(
          children: complexities
              .map(
                (c) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      right: c == complexities.last ? 0 : 8,
                    ),
                    child: OutlinedButton(
                      onPressed: () => setState(() => _complexity = c),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        side: BorderSide(
                          color: _complexity == c
                              ? AppColors.orange
                              : AppColors.border,
                          width: _complexity == c ? 1.5 : 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: _complexity == c
                            ? AppColors.orange
                            : AppColors.ink,
                        backgroundColor: _complexity == c
                            ? AppColors.orangeLt
                            : Colors.white,
                      ),
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _modeSection() {
    final modes = [
      (
        id: 'rush',
        label: 'Rush',
        fee: '+ ₱50',
        color: AppColors.orange,
        bg: AppColors.orangeLt,
        desc: 'Priority dispatch. Worker notified immediately.',
      ),
      (
        id: 'standard',
        label: 'Standard',
        fee: '₱0',
        color: AppColors.plum,
        bg: const Color(0xFFF5F0FF),
        desc: 'Posted to community board. Best for non-urgent chores.',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('SERVICE MODE'),
        const SizedBox(height: 8),
        ...modes.map((m) {
          final on = _mode == m.id;
          return GestureDetector(
            onTap: () => setState(() => _mode = m.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: m.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: m.color.withValues(alpha: on ? 0.4 : 0.2),
                  width: on ? 2 : 1,
                ),
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: m.color.withValues(alpha: 0.13),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: on
                            ? m.color
                            : Colors.black.withValues(alpha: 0.12),
                        width: 3,
                      ),
                    ),
                    child: on
                        ? Center(
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: m.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              m.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: m.color,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: m.color.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                m.fee,
                                style: TextStyle(fontSize: 11, color: m.color),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          m.desc,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.ink.withValues(alpha: 0.5),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 20),
          GestureDetector(
            onTap: onBack,
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
              'Create Task',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  final String label;
  final String suffix;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  const _CounterCard({
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$value $suffix',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.plum,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged((value - 1).clamp(min, 100000)),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.orangeLt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.remove_rounded,
                size: 18,
                color: AppColors.orange,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onChanged((value + 1).clamp(min, 100000)),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.orangeLt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 18,
                color: AppColors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: AppColors.ink.withValues(alpha: 0.5),
      ),
    );
  }
}
