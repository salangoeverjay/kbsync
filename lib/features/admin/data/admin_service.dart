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

  /// Stream of all user documents for admin dashboard summaries.
  Stream<QuerySnapshot> usersStream() {
    return _firestore.collection('users').snapshots();
  }

  /// Stream of users by verification status.
  Stream<QuerySnapshot> usersByStatusStream(String status) {
    return _firestore
        .collection('users')
        .where('verificationStatus', isEqualTo: status)
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

  /// Stream of pending users awaiting approval.
  Stream<QuerySnapshot> pendingUsersStream() {
    return _firestore
        .collection('users')
        .where('verificationStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream of platform wallet transactions only.
  Stream<QuerySnapshot> platformTransactionsStream() {
    return _firestore
        .collection('wallet_transactions')
        .where('userId', isEqualTo: 'platform')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Approve a user.
  Future<void> approveUser(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'status': 'approved',
      'verificationStatus': 'approved',
      'isVerified': true,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Disapprove/Decline a user.
  Future<void> disapproveUser(String userId, {String? reason}) async {
    await _firestore.collection('users').doc(userId).update({
      'status': 'declined',
      'verificationStatus': 'declined',
      'isVerified': false,
      'declinedAt': FieldValue.serverTimestamp(),
      'declineReason': reason ?? 'Admin decision',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Withdraw platform funds to an external account and create a debit record.
  Future<void> withdrawPlatformFunds({
    required int amount,
    required String method,
    required String accountName,
    required String accountNumber,
  }) async {
    if (amount <= 0) {
      throw StateError('Amount must be greater than zero.');
    }

    final txRef = _firestore.collection('wallet_transactions').doc();

    await _firestore.runTransaction((tx) async {
      final platformSnap = await tx.get(_platformDoc);
      final rawData = platformSnap.data();
      final data = rawData is Map<String, dynamic>
          ? rawData
          : <String, dynamic>{};
      final currentBalance = (data['balance'] as num?)?.toInt() ?? 0;

      if (currentBalance < amount) {
        throw StateError('Insufficient platform wallet balance.');
      }

      tx.set(_platformDoc, {
        'balance': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(txRef, {
        'userId': 'platform',
        'type': 'debit',
        'amount': amount,
        'meta': 'Admin withdrawal via $method',
        'accountName': accountName,
        'accountNumber': accountNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
