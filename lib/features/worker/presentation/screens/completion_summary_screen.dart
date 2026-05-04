import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/widgets/kb_buttons.dart';

class CompletionSummaryScreen extends StatefulWidget {
  const CompletionSummaryScreen({super.key});

  @override
  State<CompletionSummaryScreen> createState() =>
      _CompletionSummaryScreenState();
}

class _CompletionSummaryScreenState extends State<CompletionSummaryScreen> {
  int _rating = 5;
  late Future<_CompletionData> _dataFuture;
  String? _taskId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    if (id != _taskId) {
      _taskId = id;
      _dataFuture = _loadCompletionData(id);
    }
  }

  Future<_CompletionData> _loadCompletionData(String? taskId) async {
    if (taskId == null || taskId.isEmpty) {
      throw StateError('Missing task context.');
    }
    final firestore = FirebaseFirestore.instance;
    final results = await Future.wait([
      firestore.collection('tasks').doc(taskId).get(),
      firestore
          .collection('tasks')
          .doc(taskId)
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
    return _CompletionData.fromDocs(taskSnap.data()!, evidenceSnap.docs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FutureBuilder<_CompletionData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Column(
              children: [
                Container(
                  color: AppColors.plum,
                  child: SafeArea(
                    bottom: false,
                    child: _SummaryHeader(
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.orange,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                Container(
                  color: AppColors.plum,
                  child: SafeArea(
                    bottom: false,
                    child: _SummaryHeader(
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load summary: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.ink),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          final data = snapshot.data!;
          return Column(
            children: [
              Container(
                color: AppColors.plum,
                child: SafeArea(
                  bottom: false,
                  child: _SummaryHeader(
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: AppColors.grad,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  data.workerInitial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TASK COMPLETED!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: -0.6,
                                    color: AppColors.plum,
                                  ),
                                ),
                                Text(
                                  'Please verify the details below',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppColors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 160),
                        child: Column(
                          children: [
                            _TaskLogsCard(
                              beforeBytes: data.beforePhotoBytes,
                              beforeUrl: data.beforePhotoUrl,
                              afterBytes: data.afterPhotoBytes,
                            ),
                            const SizedBox(height: 14),
                            _TaskDetailsCard(rows: data.detailRows()),
                            const SizedBox(height: 14),
                            _RatingCard(
                              rating: _rating,
                              onRate: (r) => setState(() => _rating = r),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomSheet: _StickyActions(
        onProceed: () => Navigator.of(
          context,
        ).pushReplacementNamed(AppRoutes.workerDashboard),
      ),
    );
  }
}

class _CompletionData {
  final String service;
  final String workerName;
  final String total;
  final String? beforePhotoUrl;
  final Uint8List? beforePhotoBytes;
  final Uint8List? afterPhotoBytes;
  final DateTime? entranceAt;
  final DateTime? exitAt;
  final double? exitLat;
  final double? exitLng;
  final double? entranceFaceScore;
  final double? exitFaceScore;

  const _CompletionData({
    required this.service,
    required this.workerName,
    required this.total,
    required this.beforePhotoUrl,
    required this.beforePhotoBytes,
    required this.afterPhotoBytes,
    required this.entranceAt,
    required this.exitAt,
    required this.exitLat,
    required this.exitLng,
    required this.entranceFaceScore,
    required this.exitFaceScore,
  });

  factory _CompletionData.fromDocs(
    Map<String, dynamic> task,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> evidence,
  ) {
    final referencePhotoUrl =
        (task['referencePhotoUrl'] as String?)?.trim() ?? '';
    String? beforeUrl;
    Uint8List? beforeBytes;
    if (referencePhotoUrl.startsWith('data:')) {
      final commaIdx = referencePhotoUrl.indexOf(',');
      if (commaIdx != -1) {
        try {
          beforeBytes = base64Decode(referencePhotoUrl.substring(commaIdx + 1));
        } catch (_) {}
      }
    } else if (referencePhotoUrl.isNotEmpty) {
      beforeUrl = referencePhotoUrl;
    }

    Uint8List? afterBytes;
    if (evidence.isNotEmpty) {
      final encoded =
          (evidence.first.data()['imageBase64'] as String?)?.trim() ?? '';
      if (encoded.isNotEmpty) {
        try {
          afterBytes = base64Decode(encoded);
        } catch (_) {}
      }
    }

    final scans = (task['scans'] as Map<String, dynamic>?) ?? const {};
    final entrance = (scans['entrance'] as Map<String, dynamic>?) ?? const {};
    final exit = (scans['exit'] as Map<String, dynamic>?) ?? const {};

    DateTime? toDate(Object? v) =>
        v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
    double? toDouble(Object? v) => v is num ? v.toDouble() : null;

    return _CompletionData(
      service: (task['service'] as String?)?.trim() ?? 'Task',
      workerName: (task['worker'] as String?)?.trim() ?? 'Worker',
      total: (task['total'] as String?)?.trim() ?? '',
      beforePhotoUrl: beforeUrl,
      beforePhotoBytes: beforeBytes,
      afterPhotoBytes: afterBytes,
      entranceAt: toDate(entrance['at']),
      exitAt: toDate(exit['at']),
      exitLat: toDouble(exit['lat']),
      exitLng: toDouble(exit['lng']),
      entranceFaceScore: toDouble(entrance['faceMatchScore']),
      exitFaceScore: toDouble(exit['faceMatchScore']),
    );
  }

  String get workerInitial => workerName.isEmpty
      ? '?'
      : workerName.trim().substring(0, 1).toUpperCase();

  String _formatTime(DateTime t) {
    final local = t.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    return '${hour.toString().padLeft(2, '0')}:$minute';
  }

  String get _durationLabel {
    final s = entranceAt;
    final e = exitAt;
    if (s == null || e == null) {
      return '—';
    }
    final diff = e.difference(s);
    if (diff.inMinutes < 1) {
      return '< 1 min (${_formatTime(s)} – ${_formatTime(e)})';
    }
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final hm = h > 0 ? '${h}h ${m}m' : '${m}m';
    return '$hm (${_formatTime(s)} – ${_formatTime(e)})';
  }

  String get _geoLabel {
    if (exitLat == null || exitLng == null) return '—';
    final lat = exitLat!;
    final lng = exitLng!;
    return '${lat.toStringAsFixed(4)} ${lat >= 0 ? 'N' : 'S'}, '
        '${lng.abs().toStringAsFixed(4)} ${lng >= 0 ? 'E' : 'W'}';
  }

  String get _authLabel {
    final scores = <double>[?entranceFaceScore, ?exitFaceScore];
    if (scores.isEmpty) return 'Verified';
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    return '${avg.round()}% Secure & Matched';
  }

  /// (label, value, isAccent)
  List<(String, String, bool)> detailRows() {
    return [
      ('Service Category', service, false),
      ('Geo-Coordinate', _geoLabel, false),
      ('Authentication', _authLabel, false),
      ('Labor Duration', _durationLabel, false),
      ('Total Earned', total.isEmpty ? '—' : total, true),
    ];
  }
}

class _SummaryHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _SummaryHeader({required this.onBack});

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
          const Text(
            'Completion Summary',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskLogsCard extends StatelessWidget {
  final Uint8List? beforeBytes;
  final String? beforeUrl;
  final Uint8List? afterBytes;

  const _TaskLogsCard({
    required this.beforeBytes,
    required this.beforeUrl,
    required this.afterBytes,
  });

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Task Logs',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: -0.4,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _LogTile(
                label: 'BEFORE',
                fallbackEmoji: '🏚️',
                bytes: beforeBytes,
                url: beforeUrl,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3C1226), Color(0xFF911B44)],
                ),
              ),
              const SizedBox(width: 10),
              _LogTile(
                label: 'AFTER',
                fallbackEmoji: '✨',
                bytes: afterBytes,
                url: null,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF006C4F), Color(0xFF0891B2)],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final String label;
  final String fallbackEmoji;
  final Uint8List? bytes;
  final String? url;
  final LinearGradient gradient;
  const _LogTile({
    required this.label,
    required this.fallbackEmoji,
    required this.bytes,
    required this.url,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 150,
          decoration: BoxDecoration(gradient: gradient),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bytes != null)
                Image.memory(
                  bytes!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stackTrace) =>
                      _emojiFallback(fallbackEmoji),
                )
              else if (url != null && url!.isNotEmpty)
                Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stackTrace) =>
                      _emojiFallback(fallbackEmoji),
                )
              else
                _emojiFallback(fallbackEmoji),
              // Dark gradient + label
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emojiFallback(String emoji) {
    return Center(
      child: Text(
        emoji,
        style: TextStyle(
          fontSize: 44,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _TaskDetailsCard extends StatelessWidget {
  final List<(String, String, bool)> rows;
  const _TaskDetailsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Task Details',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.asMap().entries.map(
            (e) => Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: e.key < rows.length - 1
                    ? Border(bottom: BorderSide(color: AppColors.border))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.value.$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink.withValues(alpha: 0.5),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      e.value.$2,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: e.value.$3 ? AppColors.green : AppColors.plum,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRate;
  const _RatingCard({required this.rating, required this.onRate});

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Rate your experience',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => GestureDetector(
                onTap: () => onRate(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.star_rounded,
                    size: 36,
                    color: i < rating
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyActions extends StatelessWidget {
  final VoidCallback onProceed;
  const _StickyActions({required this.onProceed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.transparent,
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppColors.bg, AppColors.bg.withValues(alpha: 0)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '*The resident will verify the task and release payment if approved.',
            style: TextStyle(
              fontFamily: 'PublicSans',
              fontSize: 11,
              color: AppColors.ink.withValues(alpha: 0.5),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          KbGradientButton(text: 'Return to Dashboard', onTap: onProceed),
          const SizedBox(height: 10),
          KbGhostButton(text: 'Report a Problem', onTap: () {}),
        ],
      ),
    );
  }
}
