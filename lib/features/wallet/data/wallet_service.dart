import 'package:cloud_firestore/cloud_firestore.dart';

class WalletAccountData {
  final double balance;
  final double trustBond;

  const WalletAccountData({required this.balance, required this.trustBond});

  static const empty = WalletAccountData(balance: 0, trustBond: 30);
}

class WalletTransaction {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime createdAt;
  final bool isCredit;
  final String category;

  const WalletTransaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.createdAt,
    required this.isCredit,
    required this.category,
  });

  factory WalletTransaction.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final amount = _parseAmount(data['amount']);
    final isCredit = (data['isCredit'] as bool?) ?? amount >= 0;
    final createdAtRaw = data['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : DateTime.now();

    return WalletTransaction(
      id: doc.id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : (isCredit ? 'Cash In' : 'Task Payment'),
      subtitle: (data['subtitle'] as String?)?.trim().isNotEmpty == true
          ? (data['subtitle'] as String).trim()
          : (isCredit ? 'Wallet Top-Up' : 'Service Payment'),
      amount: amount,
      createdAt: createdAt,
      isCredit: isCredit,
      category:
          (data['category'] as String?)?.trim() ??
          (isCredit ? 'cash_in' : 'debit'),
    );
  }

  static double _parseAmount(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      return double.tryParse(normalized) ?? 0;
    }
    return 0;
  }
}

class WalletService {
  final FirebaseFirestore _firestore;

  WalletService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _transactions(String uid) {
    return _userDoc(uid).collection('wallet_transactions');
  }

  Stream<WalletAccountData> watchAccount(String uid) {
    return _userDoc(uid).snapshots().map((snapshot) {
      final data = snapshot.data() ?? const <String, dynamic>{};
      return WalletAccountData(
        balance: _parseAmount(data['walletBalance']),
        trustBond: _parseAmount(data['trustBond']).clamp(0, 1000000),
      );
    });
  }

  Stream<List<WalletTransaction>> watchTransactions(
    String uid, {
    int limit = 50,
  }) {
    return _transactions(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(WalletTransaction.fromDoc)
              .toList(growable: false),
        );
  }

  Future<void> recordCashIn({
    required String uid,
    required double amount,
    required String sourceName,
  }) async {
    final txRef = _transactions(uid).doc();
    final batch = _firestore.batch();

    batch.set(_userDoc(uid), {
      'walletBalance': FieldValue.increment(amount),
      'trustBond': FieldValue.increment(0),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(txRef, {
      'title': 'Cash In',
      'subtitle': '$sourceName Top-Up',
      'amount': amount,
      'isCredit': true,
      'category': 'cash_in',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  static double _parseAmount(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      return double.tryParse(normalized) ?? 0;
    }
    return 0;
  }
}
