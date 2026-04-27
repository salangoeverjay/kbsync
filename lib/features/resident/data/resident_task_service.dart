import 'package:cloud_firestore/cloud_firestore.dart';

class ResidentTaskRecord {
  final String id;
  final String icon;
  final String title;
  final String service;
  final double totalAmount;
  final DateTime createdAt;
  final String worker;
  final String statusLabel;
  final bool isOrange;
  final String time;
  final double? rating;

  const ResidentTaskRecord({
    required this.id,
    required this.icon,
    required this.title,
    required this.service,
    required this.totalAmount,
    required this.createdAt,
    required this.worker,
    required this.statusLabel,
    required this.isOrange,
    required this.time,
    this.rating,
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

    return ResidentTaskRecord(
      id: doc.id,
      icon: (data['icon'] as String?)?.trim() ?? '🧹',
      title: (data['title'] as String?)?.trim() ?? '$service – $areaLabel',
      service: service,
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
    required String complexity,
    required String mode,
    required String total,
    required List<String> groceryItems,
    double? groceryBudget,
    required String paymentProtocol,
    String? merchantQrPayload,
    String? notes,
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
      'complexity': complexity,
      'statusLabel': 'Open',
      'isOrange': true,
      'worker': 'Awaiting worker',
      'mode': mode,
      'total': total,
      'groceryItems': groceryItems,
      'groceryBudget': groceryBudget,
      'paymentProtocol': paymentProtocol,
      'merchantQrPayload': merchantQrPayload,
      'notes': notes ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    };
    batch.set(ref, payload);
    batch.set(tasksRoot, payload);
    await batch.commit();
    return ref;
  }

  Future<void> deleteTask({
    required String uid,
    required String taskId,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_tasksCollection(uid).doc(taskId));
    batch.delete(_firestore.collection('tasks').doc(taskId));
    await batch.commit();
  }
}
