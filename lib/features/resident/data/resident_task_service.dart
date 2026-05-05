import 'package:cloud_firestore/cloud_firestore.dart';

class ResidentTaskRecord {
  final String id;
  final String icon;
  final String title;
  final String service;
  final String workerUid;
  final double totalAmount;
  final DateTime createdAt;
  final String worker;
  final String statusLabel;
  final bool isOrange;
  final String time;
  final double? rating;
  final DateTime? paymentReleasedAt;

  const ResidentTaskRecord({
    required this.id,
    required this.icon,
    required this.title,
    required this.service,
    required this.workerUid,
    required this.totalAmount,
    required this.createdAt,
    required this.worker,
    required this.statusLabel,
    required this.isOrange,
    required this.time,
    this.rating,
    this.paymentReleasedAt,
  });

  factory ResidentTaskRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    final timestamp = createdAt is Timestamp
        ? createdAt.toDate()
        : DateTime.now();
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final time = '$displayHour:$minute $period';

    final service = (data['service'] as String?)?.trim() ?? 'Task';
    final areas =
        (data['areas'] as List?)
            ?.whereType<String>()
            .map((area) => area.trim())
            .where((area) => area.isNotEmpty)
            .toList() ??
        const <String>[];
    final areaLabel = areas.isEmpty ? 'General' : areas.join(', ');
    final totalAmount = _parseAmount(data['total']);

    final rating = data['rating'];
    final parsedRating = rating is num ? rating.toDouble() : null;
    final payment =
        (data['payment'] as Map?)?.cast<String, dynamic>() ?? const {};
    final releasedAtRaw = payment['releasedAt'];
    final paymentReleasedAt = releasedAtRaw is Timestamp
        ? releasedAtRaw.toDate()
        : null;

    return ResidentTaskRecord(
      id: doc.id,
      icon: (data['icon'] as String?)?.trim() ?? '🧹',
      title: (data['title'] as String?)?.trim() ?? '$service – $areaLabel',
      service: service,
      workerUid: (data['workerUid'] as String?)?.trim() ?? '',
      totalAmount: totalAmount,
      createdAt: timestamp,
      worker: (data['worker'] as String?)?.trim().isNotEmpty == true
          ? (data['worker'] as String).trim()
          : 'Awaiting worker',
      statusLabel: (data['statusLabel'] as String?)?.trim() ?? 'Open',
      isOrange: (data['isOrange'] as bool?) ?? true,
      time: (data['time'] as String?)?.trim().isNotEmpty == true
          ? (data['time'] as String).trim()
          : time,
      rating: parsedRating,
      paymentReleasedAt: paymentReleasedAt,
    );
  }

  static double _parseAmount(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final normalized = value.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(normalized) ?? 0;
    }

    return 0;
  }
}

class ResidentTaskService {
  final FirebaseFirestore _firestore;

  ResidentTaskService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tasksCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('active_tasks');
  }

  Stream<List<ResidentTaskRecord>> watchActiveTasks(String uid) {
    return _tasksCollection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ResidentTaskRecord.fromDoc)
              .toList(growable: false),
        );
  }

  Future<DocumentReference<Map<String, dynamic>>> publishTask({
    required String uid,
    required String ownerName,
    required String service,
    required List<String> areas,
    required String icon,
    String? complexity,
    required String mode,
    required String total,
    required List<String> groceryItems,
    double? groceryBudget,
    required String paymentProtocol,
    String? merchantQrPayload,
    List<String> cleaningTargets = const <String>[],
    String? referencePhotoUrl,
    String? notes,
    double? latitude,
    double? longitude,
  }) async {
    final areaLabel = areas.isEmpty ? 'General' : areas.join(', ');
    final ref = _tasksCollection(uid).doc();
    final tasksRoot = _firestore.collection('tasks').doc(ref.id);
    final batch = _firestore.batch();
    final payload = {
      'taskId': ref.id,
      'ownerId': uid,
      'ownerName': ownerName,
      'service': service,
      'title': '$service – $areaLabel',
      'areas': areas,
      'icon': icon,
      'statusLabel': 'Open',
      'isOrange': true,
      'worker': 'Awaiting worker',
      'mode': mode,
      'total': total,
      'groceryItems': groceryItems,
      'groceryBudget': groceryBudget,
      'paymentProtocol': paymentProtocol,
      'merchantQrPayload': merchantQrPayload,
      'cleaningTargets': cleaningTargets,
      'referencePhotoUrl': referencePhotoUrl,
      'notes': notes ?? '',
      'location': (latitude != null && longitude != null)
          ? GeoPoint(latitude, longitude)
          : null,
      'locationLocked': (latitude != null && longitude != null),
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (complexity != null && complexity.trim().isNotEmpty) {
      payload['complexity'] = complexity.trim();
    }
    batch.set(ref, payload);
    batch.set(tasksRoot, payload);
    await batch.commit();
    return ref;
  }

  Future<void> deleteTask({required String uid, required String taskId}) async {
    final batch = _firestore.batch();
    batch.delete(_tasksCollection(uid).doc(taskId));
    batch.delete(_firestore.collection('tasks').doc(taskId));
    await batch.commit();
  }

  Future<void> resolveTaskPayment({
    required String uid,
    required String taskId,
    required bool approved,
    int? rating,
  }) async {
    if (approved) {
      if (rating == null || rating < 1 || rating > 5) {
        throw ArgumentError('Approved tasks must include a 1-5 star rating.');
      }
    }
    final taskRef = _firestore.collection('tasks').doc(taskId);
    final residentCopyRef = _tasksCollection(uid).doc(taskId);

    await _firestore.runTransaction((tx) async {
      final taskSnap = await tx.get(taskRef);
      if (!taskSnap.exists) {
        throw StateError('Task no longer exists.');
      }

      final task = taskSnap.data() ?? const <String, dynamic>{};
      final ownerId = (task['ownerId'] as String?)?.trim() ?? '';
      if (ownerId != uid) {
        throw StateError('You can only review your own task.');
      }

      final statusLabel =
          (task['statusLabel'] as String?)?.trim().toLowerCase() ?? '';
      if (statusLabel != 'completed') {
        throw StateError(
          'The task must be completed before you can review it.',
        );
      }

      final review =
          (task['review'] as Map?)?.cast<String, dynamic>() ?? const {};
      final reviewStatus =
          (review['status'] as String?)?.trim().toLowerCase() ?? '';
      if (reviewStatus == 'approved' || reviewStatus == 'declined') {
        throw StateError('This task has already been reviewed.');
      }

      final workerUid = (task['workerUid'] as String?)?.trim() ?? '';
      if (workerUid.isEmpty) {
        throw StateError('Worker assignment is missing.');
      }

      final amount = _parseAmount(task['total']);
      if (amount <= 0) {
        throw StateError('Task amount is invalid.');
      }

      final workerRef = _firestore.collection('users').doc(workerUid);
      final residentRef = _firestore.collection('users').doc(uid);
      final workerTxRef = workerRef.collection('wallet_transactions').doc();
      final residentTxRef = residentRef.collection('wallet_transactions').doc();
      final topLevelWorkerTxRef = _firestore
          .collection('wallet_transactions')
          .doc();
      final topLevelResidentTxRef = _firestore
          .collection('wallet_transactions')
          .doc();
      final platformFeeTxRef = _firestore
          .collection('wallet_transactions')
          .doc();

      // Calculate 10% service fee
      final serviceFee = amount * 0.10;
      final totalDebit = amount + serviceFee;

      final workerName = (task['worker'] as String?)?.trim().isNotEmpty == true
          ? (task['worker'] as String).trim()
          : 'Worker';
      final escrow =
          (task['escrow'] as Map?)?.cast<String, dynamic>() ?? const {};
      final escrowStatus =
          (escrow['status'] as String?)?.trim().toLowerCase() ?? '';
      final usesEscrow = escrowStatus == 'funded';

      if (approved) {
        // Read worker doc inside the transaction so rating average + count
        // stay consistent under concurrent reviews.
        final workerSnap = await tx.get(workerRef);
        final workerData = workerSnap.data() ?? const <String, dynamic>{};
        final prevRating = _parseAmount(workerData['rating']);
        final prevCount = (workerData['ratingCount'] as num?)?.toInt() ?? 0;
        final newCount = prevCount + 1;
        final newAverage = ((prevRating * prevCount) + rating!) / newCount;
        final completedTasks =
            (workerData['completedTasks'] as num?)?.toInt() ?? 0;

        if (!usesEscrow) {
          final residentSnap = await tx.get(residentRef);
          final residentData = residentSnap.data() ?? const <String, dynamic>{};
          final balance = _parseAmount(residentData['walletBalance']);
          if (balance < totalDebit) {
            throw StateError(
              'Not enough wallet balance to pay this worker (includes 10% service fee).',
            );
          }

          tx.update(residentRef, {
            'walletBalance': FieldValue.increment(-totalDebit),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          tx.set(residentTxRef, {
            'title': 'Task Payment',
            'subtitle': 'Paid to $workerName',
            'amount': -totalDebit,
            'isCredit': false,
            'category': 'task_payment',
            'taskId': taskId,
            'serviceFee': serviceFee,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Record in top-level collection for admin visibility
          tx.set(topLevelResidentTxRef, {
            'userId': uid,
            'userName': uid,
            'type': 'debit',
            'amount': (totalDebit * 100).toInt(),
            'meta': 'Task Payment to $workerName',
            'taskId': taskId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        tx.set(workerRef, {
          'walletBalance': FieldValue.increment(amount),
          'rating': double.parse(newAverage.toStringAsFixed(2)),
          'ratingCount': newCount,
          'completedTasks': completedTasks + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        tx.set(workerTxRef, {
          'title': 'Task Payment',
          'subtitle': 'From resident',
          'amount': amount,
          'isCredit': true,
          'category': 'task_payment',
          'taskId': taskId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Record worker payment in top-level collection for admin visibility
        tx.set(topLevelWorkerTxRef, {
          'userId': workerUid,
          'userName': workerName,
          'type': 'credit',
          'amount': (amount * 100).toInt(),
          'meta': 'Task Payment from resident',
          'taskId': taskId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Record platform fee in top-level collection and increment platform balance
        final platformRef = _firestore
            .collection('platform_accounts')
            .doc('platform');
        tx.set(platformRef, {
          'balance': FieldValue.increment((serviceFee * 100).toInt()),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        tx.set(platformFeeTxRef, {
          'userId': 'platform',
          'type': 'credit',
          'amount': (serviceFee * 100).toInt(),
          'meta': 'Service fee from task $taskId',
          'taskId': taskId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final taskPatch = <String, dynamic>{
          'statusLabel': 'Approved',
          'isOrange': false,
          'rating': rating,
          'review': {
            'status': 'approved',
            'reviewedBy': uid,
            'reviewedAt': FieldValue.serverTimestamp(),
            'rating': rating,
          },
          'payment': {
            'status': 'released',
            'amount': amount,
            'releasedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (usesEscrow) {
          taskPatch['escrow'] = {
            'status': 'released',
            'amount': amount,
            'releasedAt': FieldValue.serverTimestamp(),
          };
        }

        tx.set(taskRef, taskPatch, SetOptions(merge: true));
        tx.set(residentCopyRef, taskPatch, SetOptions(merge: true));
        return;
      }

      final taskPatch = <String, dynamic>{
        'statusLabel': 'Declined',
        'isOrange': true,
        'review': {
          'status': 'declined',
          'reviewedBy': uid,
          'reviewedAt': FieldValue.serverTimestamp(),
        },
        'payment': {
          'status': 'declined',
          'amount': amount,
          'declinedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (usesEscrow) {
        taskPatch['escrow'] = {
          'status': 'declined',
          'amount': amount,
          'declinedAt': FieldValue.serverTimestamp(),
        };
      }

      tx.set(taskRef, taskPatch, SetOptions(merge: true));
      tx.set(residentCopyRef, taskPatch, SetOptions(merge: true));
    });
  }

  static double _parseAmount(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final normalized = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      return double.tryParse(normalized) ?? 0;
    }

    return 0;
  }
}
