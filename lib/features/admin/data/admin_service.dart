import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseFirestore _firestore;

  AdminService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference get _platformDoc =>
      _firestore.collection('platform_accounts').doc('platform');

  /// Ensure a default platform account document exists.
  Future<void> ensureDefaultPlatformAccount() async {
    final doc = await _platformDoc.get();
    if (!doc.exists) {
      await _platformDoc.set({
        'balance': 0,
        'currency': 'PHP',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Stream of wallet transactions for admin list view.
  Stream<QuerySnapshot> transactionsStream() {
    return _firestore
        .collection('wallet_transactions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream for platform account doc.
  Stream<DocumentSnapshot> platformAccountStream() {
    return _platformDoc.snapshots();
  }

  /// Create a platform credit transaction (used when taking fee).
  Future<void> creditPlatformFee({
    required int amount,
    required String taskId,
    Map<String, dynamic>? meta,
  }) async {
    final txRef = _firestore.collection('wallet_transactions').doc();
    await txRef.set({
      'userId': 'platform',
      'type': 'credit',
      'amount': amount,
      'taskId': taskId,
      'meta': meta ?? {'reason': 'service_fee'},
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Increment platform balance atomically
    await _platformDoc.set({
      'balance': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
