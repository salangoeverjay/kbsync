import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/widgets/kb_buttons.dart';
import 'package:kbsync/features/resident/data/resident_task_service.dart';

class ResidentTaskReviewSheet extends StatefulWidget {
  final ResidentTaskRecord task;

  const ResidentTaskReviewSheet({required this.task, super.key});

  @override
  State<ResidentTaskReviewSheet> createState() =>
      _ResidentTaskReviewSheetState();
}

class _ResidentTaskReviewSheetState extends State<ResidentTaskReviewSheet> {
  final ResidentTaskService _taskService = ResidentTaskService();
  late final Future<_ResidentTaskReviewData> _reviewFuture;
  bool _isResolving = false;
  int _rating = 5;

  @override
  void initState() {
    super.initState();
    _reviewFuture = _loadReviewData();
  }

  Future<_ResidentTaskReviewData> _loadReviewData() async {
    final firestore = FirebaseFirestore.instance;
    final results = await Future.wait([
      firestore.collection('tasks').doc(widget.task.id).get(),
      firestore
          .collection('tasks')
          .doc(widget.task.id)
          .collection('evidence')
          .orderBy('index')
          .limit(1)
          .get(),
    ]);

    final taskSnap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final evidenceSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    if (!taskSnap.exists) {
      throw StateError('Task no longer exists.');
    }

    final data = taskSnap.data() ?? const <String, dynamic>{};
    Uint8List? evidenceBytes;
    String? evidenceUrl;
    if (evidenceSnap.docs.isNotEmpty) {
      final encoded =
          (evidenceSnap.docs.first.data()['imageBase64'] as String?)?.trim() ??
          '';
      if (encoded.isNotEmpty) {
        try {
          evidenceBytes = base64Decode(encoded);
        } catch (_) {}
      }
      final maybeUrl =
          (evidenceSnap.docs.first.data()['imageUrl'] as String?)?.trim() ?? '';
      if (maybeUrl.isNotEmpty) {
        evidenceUrl = maybeUrl;
      }
    }

    final referencePhotoUrl =
        (data['referencePhotoUrl'] as String?)?.trim() ?? '';
    final workerName = (data['worker'] as String?)?.trim().isNotEmpty == true
        ? (data['worker'] as String).trim()
        : widget.task.worker;
    final statusLabel =
        (data['statusLabel'] as String?)?.trim().isNotEmpty == true
        ? (data['statusLabel'] as String).trim()
        : widget.task.statusLabel;
    final total = (data['total'] as String?)?.trim().isNotEmpty == true
        ? (data['total'] as String).trim()
        : _formatAmount(widget.task.totalAmount);

    return _ResidentTaskReviewData(
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : widget.task.title,
      workerName: workerName,
      statusLabel: statusLabel,
      total: total,
      referencePhotoUrl: referencePhotoUrl,
      evidenceBytes: evidenceBytes,
      evidenceUrl: evidenceUrl,
      service: (data['service'] as String?)?.trim().isNotEmpty == true
          ? (data['service'] as String).trim()
          : widget.task.service,
    );
  }

  Future<void> _resolve(bool approved) async {
    if (_isResolving) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) return;

    setState(() => _isResolving = true);
    try {
      await _taskService.resolveTaskPayment(
        uid: userId,
        taskId: widget.task.id,
        approved: approved,
        rating: approved ? _rating : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(approved);
    } catch (error) {
      if (!mounted) return;
      String message = 'Could not update payment';
      if (error is StateError) {
        message = error.message;
      } else if (error is Exception) {
        message = error.toString().replaceAll('Exception: ', '');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.orange,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResolving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: FutureBuilder<_ResidentTaskReviewData>(
            future: _reviewFuture,
            builder: (context, snapshot) {
              final loading = snapshot.connectionState != ConnectionState.done;
              final data = snapshot.data;
              if (snapshot.hasError) {
                return SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Verify Before Payment',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: AppColors.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Could not load task review: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.ink.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 16),
                        KbGhostButton(
                          text: 'Close',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SafeArea(
                top: false,
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.ink.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const Text(
                        'Verify Before Payment',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: AppColors.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review the worker output first. Only approve if the task is acceptable.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.ink.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.orange,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        _HeaderCard(data: data!),
                        const SizedBox(height: 14),
                        _EvidenceCard(
                          title: 'Reference Photo',
                          label: data.referencePhotoUrl.isEmpty
                              ? 'No reference photo'
                              : 'Resident provided reference',
                          imageBytes: null,
                          imageUrl: data.referencePhotoUrl,
                          fallbackIcon: Icons.photo_library_outlined,
                          accent: AppColors.plum,
                        ),
                        const SizedBox(height: 12),
                        _EvidenceCard(
                          title: 'Worker Evidence',
                          label:
                              data.evidenceBytes != null ||
                                  (data.evidenceUrl?.isNotEmpty == true)
                              ? 'Captured at completion'
                              : 'No evidence uploaded yet',
                          imageBytes: data.evidenceBytes,
                          imageUrl: data.evidenceUrl,
                          fallbackIcon: Icons.camera_alt_outlined,
                          accent: AppColors.orange,
                        ),
                        const SizedBox(height: 14),
                        _DetailTable(data: data),
                        const SizedBox(height: 18),
                        if (widget.task.statusLabel.toLowerCase() !=
                            'completed')
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.orangeLt.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'This task is not ready for review yet.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.ink.withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        else ...[
                          _RatingPicker(
                            rating: _rating,
                            enabled: !_isResolving,
                            onChanged: (r) => setState(() => _rating = r),
                          ),
                          const SizedBox(height: 14),
                          KbGradientButton(
                            text: _isResolving
                                ? 'Saving...'
                                : 'Approve & Pay Worker',
                            onTap: _isResolving ? null : () => _resolve(true),
                          ),
                          const SizedBox(height: 10),
                          KbGhostButton(
                            text: _isResolving ? 'Saving...' : 'Decline',
                            onTap: _isResolving ? null : () => _resolve(false),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ResidentTaskReviewData {
  final String title;
  final String workerName;
  final String statusLabel;
  final String total;
  final String referencePhotoUrl;
  final Uint8List? evidenceBytes;
  final String? evidenceUrl;
  final String service;

  const _ResidentTaskReviewData({
    required this.title,
    required this.workerName,
    required this.statusLabel,
    required this.total,
    required this.referencePhotoUrl,
    required this.evidenceBytes,
    required this.evidenceUrl,
    required this.service,
  });
}

class _HeaderCard extends StatelessWidget {
  final _ResidentTaskReviewData data;
  const _HeaderCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final statusColor = data.statusLabel.toLowerCase() == 'declined'
        ? const Color(0xFFDC2626)
        : data.statusLabel.toLowerCase() == 'approved'
        ? AppColors.green
        : AppColors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Worker: ${data.workerName}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.ink.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  data.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                data.total,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.plum,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  final String title;
  final String label;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final IconData fallbackIcon;
  final Color accent;

  const _EvidenceCard({
    required this.title,
    required this.label,
    required this.imageBytes,
    required this.imageUrl,
    required this.fallbackIcon,
    required this.accent,
  });

  // Cache decoded data: URI bytes per source string so unrelated parent
  // rebuilds don't re-decode and cause Image.memory to flicker.
  static final Map<String, Uint8List> _decodedDataUriCache =
      <String, Uint8List>{};

  @override
  Widget build(BuildContext context) {
    final decodedDataUriBytes = _decodeDataUri(imageUrl);
    final resolvedBytes = imageBytes ?? decodedDataUriBytes;
    final hasImage = resolvedBytes != null || (imageUrl?.isNotEmpty == true);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.ink,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: hasImage
                  ? resolvedBytes != null
                        ? Image.memory(
                            resolvedBytes,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                        : Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) =>
                                _emptyState(),
                          )
                  : _emptyState(),
            ),
          ),
        ],
      ),
    );
  }

  Uint8List? _decodeDataUri(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty || !raw.startsWith('data:')) {
      return null;
    }
    final cached = _decodedDataUriCache[raw];
    if (cached != null) return cached;

    final commaIndex = raw.indexOf(',');
    if (commaIndex == -1 || commaIndex == raw.length - 1) {
      return null;
    }

    try {
      final decoded = base64Decode(raw.substring(commaIndex + 1));
      _decodedDataUriCache[raw] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Widget _emptyState() {
    return Container(
      color: accent.withValues(alpha: 0.08),
      child: Center(child: Icon(fallbackIcon, size: 36, color: accent)),
    );
  }
}

class _DetailTable extends StatelessWidget {
  final _ResidentTaskReviewData data;
  const _DetailTable({required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Service', data.service),
      ('Decision', data.statusLabel),
      ('Amount', data.total),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: rows
            .asMap()
            .entries
            .map(
              (entry) => Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: entry.key < rows.length - 1
                      ? Border(bottom: BorderSide(color: AppColors.border))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.value.$1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink.withValues(alpha: 0.6),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        entry.value.$2,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.plum,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _RatingPicker extends StatelessWidget {
  final int rating;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _RatingPicker({
    required this.rating,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rate the worker',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Required for approval. Updates the worker\'s public rating.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.ink.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < rating;
              return GestureDetector(
                onTap: enabled ? () => onChanged(i + 1) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.star_rounded,
                    size: 36,
                    color: filled
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

String _formatAmount(double amount) {
  final rounded = amount.round();
  final digits = rounded.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final indexFromRight = digits.length - i;
    buffer.write(digits[i]);
    if (indexFromRight > 1 && indexFromRight % 3 == 1) {
      buffer.write(',');
    }
  }

  return '₱$buffer';
}
