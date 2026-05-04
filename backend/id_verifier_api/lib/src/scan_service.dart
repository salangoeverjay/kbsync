import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'didit_client.dart';
import 'firestore_client.dart';

/// Orchestrates the entrance and exit task scans:
///
///   1. Fetch the worker's reference selfie (stored at sign-up).
///   2. Run Didit passive liveness on the new selfie.
///   3. Run Didit face match against the reference photo.
///   4. Validate GPS within 50 m of the task pin.
///   5. Track consecutive failures; lock the worker out for 5 hours after 3.
///   6. Write the audit trail to `tasks/{taskId}.scans.{entrance|exit}`.
///
/// Failures during step 1 (network/storage) are *not* counted as biometric
/// failures — only an actual `declined` decision from Didit increments the
/// failure counter. This avoids penalising workers for our own outages.
class TaskScanService {
  TaskScanService({
    required DiditClient diditClient,
    required FirestoreClient firestore,
    this.geofenceMeters = 50,
    this.maxFailures = 3,
    this.lockoutDuration = const Duration(hours: 5),
    this.faceMatchScoreThreshold = 30,
    this.livenessScoreThreshold = 30,
  })  : _diditClient = diditClient,
        _firestore = firestore;

  final DiditClient _diditClient;
  final FirestoreClient _firestore;
  final double geofenceMeters;
  final int maxFailures;
  final Duration lockoutDuration;
  final int faceMatchScoreThreshold;
  final int livenessScoreThreshold;

  /// Run an entrance scan for `taskId`/`workerUid`.
  /// Sets `tasks/{taskId}.statusLabel = 'In Progress'` on success.
  Future<TaskScanOutcome> runEntranceScan(TaskScanRequest req) {
    return _runScan(req: req, kind: _ScanKind.entrance);
  }

  /// Run an exit scan for `taskId`/`workerUid`.
  /// Sets `tasks/{taskId}.statusLabel = 'Completed'` on success.
  Future<TaskScanOutcome> runExitScan(TaskScanRequest req) {
    return _runScan(req: req, kind: _ScanKind.exit);
  }

  Future<TaskScanOutcome> _runScan({
    required TaskScanRequest req,
    required _ScanKind kind,
  }) async {
    // 0. Lockout gate.
    final lockedUntil = await _activeLockoutUntil(req.workerUid);
    if (lockedUntil != null) {
      return TaskScanOutcome.locked(lockedUntil: lockedUntil);
    }

    // 1. Reference photo lookup.
    final reference = await _fetchReferenceFace(req.workerUid);
    if (reference == null) {
      return TaskScanOutcome.error(
        code: 'no_reference_photo',
        message:
            'No verified reference selfie on file. Re-run identity verification.',
      );
    }

    // 2. Geofence check (cheap, runs before Didit calls so we don't burn
    //    a quota on a worker who is far from the pin).
    final taskDoc = await _firestore.getDoc('tasks/${req.taskId}');
    if (taskDoc == null) {
      return TaskScanOutcome.error(
        code: 'task_not_found',
        message: 'Task ${req.taskId} does not exist.',
      );
    }
    final taskLat = _asDouble(taskDoc['lat']);
    final taskLng = _asDouble(taskDoc['lng']);
    if (taskLat != null && taskLng != null) {
      final distance = _haversineMeters(
        taskLat,
        taskLng,
        req.lat,
        req.lng,
      );
      if (distance > geofenceMeters) {
        return TaskScanOutcome.outOfRange(
          distanceMeters: distance,
          allowedMeters: geofenceMeters,
        );
      }
    }
    // (If the task has no GPS, we skip geofence rather than fail closed —
    // older tasks predate the GPS field. New tasks always carry coords.)

    // 3. Liveness.
    Map<String, dynamic> livenessRaw;
    try {
      livenessRaw = await _diditClient.verifyPassiveLiveness(
        userId: req.workerUid,
        userImageBytes: req.selfieBytes,
        faceLivenessScoreDeclineThreshold: livenessScoreThreshold,
      );
    } on DiditClientException catch (e) {
      return TaskScanOutcome.error(
        code: 'didit_liveness_error',
        message: 'Didit liveness check failed: ${e.message}',
      );
    }
    final livenessApproved = _isApproved(livenessRaw['status']);

    // 4. Face match.
    Map<String, dynamic> matchRaw;
    try {
      matchRaw = await _diditClient.verifyFaceMatch(
        userId: req.workerUid,
        userImageBytes: req.selfieBytes,
        refImageBytes: reference,
        faceMatchScoreDeclineThreshold: faceMatchScoreThreshold,
      );
    } on DiditClientException catch (e) {
      return TaskScanOutcome.error(
        code: 'didit_face_match_error',
        message: 'Didit face match failed: ${e.message}',
      );
    }
    final matchApproved = _isApproved(matchRaw['status']);

    // 5. Decide.
    final passed = livenessApproved && matchApproved;
    final retriesRemaining = await _persistOutcome(
      req: req,
      kind: kind,
      passed: passed,
      livenessRaw: livenessRaw,
      matchRaw: matchRaw,
      taskDoc: taskDoc,
    );

    if (passed) {
      return TaskScanOutcome.passed(
        livenessScore: _asDouble(livenessRaw['score']),
        faceMatchScore: _asDouble(matchRaw['score']),
      );
    }

    return TaskScanOutcome.failed(
      reason: !livenessApproved ? 'liveness_failed' : 'face_match_failed',
      retriesRemaining: retriesRemaining,
      lockedUntil: retriesRemaining <= 0
          ? DateTime.now().toUtc().add(lockoutDuration)
          : null,
      livenessScore: _asDouble(livenessRaw['score']),
      faceMatchScore: _asDouble(matchRaw['score']),
    );
  }

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  Future<int> _persistOutcome({
    required TaskScanRequest req,
    required _ScanKind kind,
    required bool passed,
    required Map<String, dynamic> livenessRaw,
    required Map<String, dynamic> matchRaw,
    required Map<String, dynamic> taskDoc,
  }) async {
    final now = DateTime.now().toUtc();
    final scanField = kind == _ScanKind.entrance ? 'entrance' : 'exit';
    final isEntrancePass = passed && kind == _ScanKind.entrance;
    final isExitPass = passed && kind == _ScanKind.exit;

    final scanRecord = <String, dynamic>{
      'workerUid': req.workerUid,
      'passed': passed,
      'lat': req.lat,
      'lng': req.lng,
      'livenessStatus': livenessRaw['status']?.toString() ?? 'unknown',
      'livenessScore': _asDouble(livenessRaw['score']),
      'faceMatchStatus': matchRaw['status']?.toString() ?? 'unknown',
      'faceMatchScore': _asDouble(matchRaw['score']),
      'at': firestoreServerTimestamp,
    };

    // Build the patch for the top-level tasks/{id} doc.
    final taskPatch = <String, dynamic>{
      'scans.$scanField': scanRecord,
      if (isEntrancePass) 'statusLabel': 'In Progress',
      if (isExitPass) 'statusLabel': 'Completed',
      'updatedAt': firestoreServerTimestamp,
    };

    // Only on a passing entrance scan do we mark the task as accepted by
    // this worker. A failed scan must leave the task open so other workers
    // (and the same worker on retry) can still see it.
    if (isEntrancePass) {
      final workerName = (req.workerName?.trim().isNotEmpty == true)
          ? req.workerName!.trim()
          : 'Worker';
      taskPatch['worker'] = workerName;
      taskPatch['workerUid'] = req.workerUid;
      taskPatch['acceptedAt'] = firestoreServerTimestamp;
    }

    await _firestore.patchDoc('tasks/${req.taskId}', taskPatch);

    // Mirror the assignment to the resident's per-user copy so the
    // resident dashboard reflects who accepted the task.
    if (isEntrancePass) {
      final ownerId = (taskDoc['ownerId'] as String?)?.trim();
      if (ownerId != null && ownerId.isNotEmpty) {
        await _firestore.patchDoc(
          'users/$ownerId/active_tasks/${req.taskId}',
          {
            'worker': taskPatch['worker'],
            'workerUid': req.workerUid,
            'statusLabel': 'In Progress',
            'acceptedAt': firestoreServerTimestamp,
            'updatedAt': firestoreServerTimestamp,
          },
        );
      }
    }

    if (isExitPass) {
      final ownerId = (taskDoc['ownerId'] as String?)?.trim();
      if (ownerId != null && ownerId.isNotEmpty) {
        await _firestore.patchDoc(
          'users/$ownerId/active_tasks/${req.taskId}',
          {
            'statusLabel': 'Completed',
            'completedAt': firestoreServerTimestamp,
            'updatedAt': firestoreServerTimestamp,
          },
        );
      }
    }

    // Update worker's failure counter.
    final workerDoc =
        await _firestore.getDoc('users/${req.workerUid}') ?? <String, dynamic>{};
    final currentFailures = (workerDoc['scanFailureCount'] as int?) ?? 0;

    if (passed) {
      // Successful scan resets the streak.
      if (currentFailures != 0) {
        await _firestore.patchDoc('users/${req.workerUid}', {
          'scanFailureCount': 0,
          'updatedAt': firestoreServerTimestamp,
        });
      }
      return maxFailures;
    }

    final newFailures = currentFailures + 1;
    final retriesRemaining = math.max(0, maxFailures - newFailures);
    final shouldLock = newFailures >= maxFailures;

    await _firestore.patchDoc('users/${req.workerUid}', {
      'scanFailureCount': newFailures,
      if (shouldLock) 'workerLockoutUntil': now.add(lockoutDuration),
      'updatedAt': firestoreServerTimestamp,
    });

    return retriesRemaining;
  }

  Future<DateTime?> _activeLockoutUntil(String uid) async {
    final doc = await _firestore.getDoc('users/$uid');
    final raw = doc?['workerLockoutUntil'];
    if (raw is! DateTime) return null;
    final until = raw.toUtc();
    if (until.isAfter(DateTime.now().toUtc())) return until;
    return null;
  }

  Future<Uint8List?> _fetchReferenceFace(String uid) async {
    final doc = await _firestore.getDoc('users/$uid/private/reference_face');
    final encoded = doc?['imageBase64'];
    if (encoded is! String || encoded.isEmpty) return null;
    return base64Decode(encoded);
  }

  // ---------------------------------------------------------------------------
  // Math helpers
  // ---------------------------------------------------------------------------

  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // metres
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180);

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static bool _isApproved(dynamic raw) =>
      raw is String && raw.trim().toLowerCase() == 'approved';
}

enum _ScanKind { entrance, exit }

class TaskScanRequest {
  final String taskId;
  final String workerUid;
  final Uint8List selfieBytes;
  final double lat;
  final double lng;

  /// Display name written to the task on a passing entrance scan so the
  /// resident dashboard shows who accepted the work. Ignored for exit scans.
  final String? workerName;

  const TaskScanRequest({
    required this.taskId,
    required this.workerUid,
    required this.selfieBytes,
    required this.lat,
    required this.lng,
    this.workerName,
  });
}

/// Discriminated outcome of a scan attempt. Handlers map this to JSON.
class TaskScanOutcome {
  final TaskScanOutcomeKind kind;
  final String? reason;
  final int? retriesRemaining;
  final DateTime? lockedUntil;
  final double? distanceMeters;
  final double? allowedMeters;
  final double? livenessScore;
  final double? faceMatchScore;
  final String? errorCode;
  final String? errorMessage;

  const TaskScanOutcome._({
    required this.kind,
    this.reason,
    this.retriesRemaining,
    this.lockedUntil,
    this.distanceMeters,
    this.allowedMeters,
    this.livenessScore,
    this.faceMatchScore,
    this.errorCode,
    this.errorMessage,
  });

  factory TaskScanOutcome.passed({
    double? livenessScore,
    double? faceMatchScore,
  }) =>
      TaskScanOutcome._(
        kind: TaskScanOutcomeKind.passed,
        livenessScore: livenessScore,
        faceMatchScore: faceMatchScore,
      );

  factory TaskScanOutcome.failed({
    required String reason,
    required int retriesRemaining,
    DateTime? lockedUntil,
    double? livenessScore,
    double? faceMatchScore,
  }) =>
      TaskScanOutcome._(
        kind: TaskScanOutcomeKind.failed,
        reason: reason,
        retriesRemaining: retriesRemaining,
        lockedUntil: lockedUntil,
        livenessScore: livenessScore,
        faceMatchScore: faceMatchScore,
      );

  factory TaskScanOutcome.locked({required DateTime lockedUntil}) =>
      TaskScanOutcome._(
        kind: TaskScanOutcomeKind.locked,
        lockedUntil: lockedUntil,
      );

  factory TaskScanOutcome.outOfRange({
    required double distanceMeters,
    required double allowedMeters,
  }) =>
      TaskScanOutcome._(
        kind: TaskScanOutcomeKind.outOfRange,
        distanceMeters: distanceMeters,
        allowedMeters: allowedMeters,
      );

  factory TaskScanOutcome.error({
    required String code,
    required String message,
  }) =>
      TaskScanOutcome._(
        kind: TaskScanOutcomeKind.error,
        errorCode: code,
        errorMessage: message,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        if (reason != null) 'reason': reason,
        if (retriesRemaining != null) 'retriesRemaining': retriesRemaining,
        if (lockedUntil != null)
          'lockedUntil': lockedUntil!.toUtc().toIso8601String(),
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
        if (allowedMeters != null) 'allowedMeters': allowedMeters,
        if (livenessScore != null) 'livenessScore': livenessScore,
        if (faceMatchScore != null) 'faceMatchScore': faceMatchScore,
        if (errorCode != null) 'errorCode': errorCode,
        if (errorMessage != null) 'errorMessage': errorMessage,
      };
}

enum TaskScanOutcomeKind { passed, failed, locked, outOfRange, error }
