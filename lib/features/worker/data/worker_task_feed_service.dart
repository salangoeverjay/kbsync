import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerOpenTask {
  final String id;
  final String ownerId;
  final String ownerName;
  final String service;
  final String title;
  final List<String> areas;
  final String notes;
  final List<String> groceryItems;
  final double? groceryBudget;
  final String paymentProtocol;
  final String merchantQrPayload;
  final String icon;
  final String mode;
  final String total;
  final String complexity;
  final DateTime createdAt;

  const WorkerOpenTask({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.service,
    required this.title,
    required this.areas,
    required this.notes,
    required this.groceryItems,
    required this.groceryBudget,
    required this.paymentProtocol,
    required this.merchantQrPayload,
    required this.icon,
    required this.mode,
    required this.total,
    required this.complexity,
    required this.createdAt,
  });

  String get areaLabel => areas.isEmpty ? 'General' : areas.join(', ');

  String get groceryListLabel {
    if (groceryItems.isEmpty) return '';
    return groceryItems.join(', ');
  }

  String get groceryBudgetLabel {
    final budget = groceryBudget;
    if (budget == null || budget <= 0) return '';
    final whole = budget % 1 == 0;
    return whole
        ? '₱${budget.toStringAsFixed(0)}'
        : '₱${budget.toStringAsFixed(2)}';
  }

  bool get requiresMerchantQrPayment {
    if (paymentProtocol == 'merchant_qr') return true;
    final budget = groceryBudget;
    return serviceFilterLabel == 'Pabili' && budget != null && budget > 200;
  }

  bool get isRush => mode.toLowerCase() == 'rush';

  String get serviceFilterLabel {
    switch (service.toLowerCase()) {
      case 'grocery':
        return 'Pabili';
      case 'cleaning':
        return 'Cleaning';
      case 'laundry':
        return 'Laundry';
      case 'dishes':
        return 'Dishes';
      default:
        return service;
    }
  }

  String get timeLabel {
    final hour = createdAt.hour;
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }

  int get payout {
    final normalized = total.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(normalized)?.round() ?? 0;
  }

  factory WorkerOpenTask.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAtRaw = data['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : DateTime.now();

    final areas =
        (data['areas'] as List?)
            ?.whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList() ??
        const <String>[];

    return WorkerOpenTask(
      id: doc.id,
      ownerId: (data['ownerId'] as String?)?.trim() ?? '',
      ownerName: (data['ownerName'] as String?)?.trim().isNotEmpty == true
          ? (data['ownerName'] as String).trim()
          : 'Resident',
      service: (data['service'] as String?)?.trim() ?? 'Task',
      title: (data['title'] as String?)?.trim() ?? 'Task',
      areas: areas,
      notes: (data['notes'] as String?)?.trim() ?? '',
      groceryItems:
          (data['groceryItems'] as List?)
              ?.whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      groceryBudget: (data['groceryBudget'] as num?)?.toDouble(),
      paymentProtocol:
          (data['paymentProtocol'] as String?)?.trim() ?? 'cash_or_wallet',
      merchantQrPayload: (data['merchantQrPayload'] as String?)?.trim() ?? '',
      icon: (data['icon'] as String?)?.trim() ?? '🧹',
      mode: (data['mode'] as String?)?.trim() ?? 'standard',
      total: (data['total'] as String?)?.trim() ?? '₱0',
      complexity: (data['complexity'] as String?)?.trim() ?? 'Moderate',
      createdAt: createdAt,
    );
  }
}

class WorkerTaskFeedService {
  final FirebaseFirestore _firestore;

  WorkerTaskFeedService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<WorkerOpenTask>> watchOpenTasks() {
    return _firestore.collection('tasks').snapshots().map((snapshot) {
      final tasks =
          snapshot.docs
              .where((doc) {
                final data = doc.data();
                final ownerId = (data['ownerId'] as String?)?.trim() ?? '';
                if (ownerId.isEmpty) return false;

                final status =
                    (data['statusLabel'] as String?)?.trim().toLowerCase() ??
                    'open';
                final worker = (data['worker'] as String?)?.trim() ?? '';
                final hasAssignedWorker =
                    worker.isNotEmpty &&
                    worker.toLowerCase() != 'awaiting worker';

                return status == 'open' && !hasAssignedWorker;
              })
              .map(WorkerOpenTask.fromDoc)
              .toList(growable: true)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return tasks;
    });
  }
}
