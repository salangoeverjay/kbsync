import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads the worker's biometric-scan lockout state set by the backend.
///
/// The backend ([backend/id_verifier_api/lib/src/scan_service.dart])
/// writes `users/{uid}.workerLockoutUntil` after 3 consecutive failed
/// entrance/exit scans. This service is the read side: streams the value
/// so dashboards can disable accept buttons and show a countdown.
class WorkerLockoutState {
  final DateTime? lockedUntil;
  final int failureCount;

  const WorkerLockoutState({
    required this.lockedUntil,
    required this.failureCount,
  });

  static const empty = WorkerLockoutState(lockedUntil: null, failureCount: 0);

  /// Whether the worker is currently locked out (relative to [now]).
  bool isLocked({DateTime? now}) {
    final until = lockedUntil;
    if (until == null) return false;
    final reference = (now ?? DateTime.now()).toUtc();
    return until.toUtc().isAfter(reference);
  }

  /// Time remaining in the lockout, or `Duration.zero` if not locked.
  Duration remaining({DateTime? now}) {
    final until = lockedUntil;
    if (until == null) return Duration.zero;
    final diff =
        until.toUtc().difference((now ?? DateTime.now()).toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }
}

class WorkerLockoutService {
  WorkerLockoutService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<WorkerLockoutState> watchLockout(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data() ?? const <String, dynamic>{};
      final until = data['workerLockoutUntil'];
      final failures = data['scanFailureCount'];
      return WorkerLockoutState(
        lockedUntil: until is Timestamp ? until.toDate() : null,
        failureCount: failures is int ? failures : 0,
      );
    });
  }

  Future<WorkerLockoutState> currentLockout(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    final data = snap.data() ?? const <String, dynamic>{};
    final until = data['workerLockoutUntil'];
    final failures = data['scanFailureCount'];
    return WorkerLockoutState(
      lockedUntil: until is Timestamp ? until.toDate() : null,
      failureCount: failures is int ? failures : 0,
    );
  }
}
