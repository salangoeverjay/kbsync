import 'package:cloud_firestore/cloud_firestore.dart';

/// One in-progress task that the current worker has already passed an
/// entrance scan for, but has not yet exited (or abandoned mid-flow).
class WorkerActiveTask {
  final String id;
  final String ownerId;
  final String ownerName;
  final String service;
  final String title;
  final String icon;
  final String total;

  const WorkerActiveTask({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.service,
    required this.title,
    required this.icon,
    required this.total,
  });

  factory WorkerActiveTask.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return WorkerActiveTask(
      id: doc.id,
      ownerId: (data['ownerId'] as String?)?.trim() ?? '',
      ownerName: (data['ownerName'] as String?)?.trim() ?? '',
      service: (data['service'] as String?)?.trim() ?? 'Task',
      title: (data['title'] as String?)?.trim() ?? 'Active task',
      icon: (data['icon'] as String?)?.trim() ?? '🧹',
      total: (data['total'] as String?)?.trim() ?? '',
    );
  }
}

/// Surfaces the worker's currently in-progress task so the dashboard can
/// offer a "Continue" CTA after the worker accidentally backgrounds the
/// app, swaps tabs, or otherwise leaves the evidence log screen.
///
/// Also exposes a `cancelActiveTask` action that returns the task back
/// to the open pool (clears the worker assignment) so the resident isn't
/// stuck with an abandoned task.
class WorkerActiveTaskService {
  WorkerActiveTaskService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Streams the worker's active (in-progress) tasks. Usually 0 or 1 docs;
  /// the UI just shows the most recent.
  Stream<List<WorkerActiveTask>> watchActiveTasks(String workerUid) {
    return _firestore
        .collection('tasks')
        .where('workerUid', isEqualTo: workerUid)
        .where('statusLabel', isEqualTo: 'In Progress')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(WorkerActiveTask.fromDoc)
              .toList(growable: false),
        );
  }

  /// Returns the task to the open pool. Mirrors writes to both the
  /// resident's per-user copy and the global `tasks/{id}` doc so the
  /// resident dashboard reflects the change immediately.
  Future<void> cancelActiveTask({
    required String taskId,
    required String ownerId,
  }) async {
    final batch = _firestore.batch();
    final reset = {
      'statusLabel': 'Open',
      'isOrange': true,
      'worker': 'Awaiting worker',
      'workerUid': FieldValue.delete(),
      'acceptedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.set(
      _firestore.collection('tasks').doc(taskId),
      reset,
      SetOptions(merge: true),
    );
    if (ownerId.isNotEmpty) {
      batch.set(
        _firestore
            .collection('users')
            .doc(ownerId)
            .collection('active_tasks')
            .doc(taskId),
        reset,
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}
