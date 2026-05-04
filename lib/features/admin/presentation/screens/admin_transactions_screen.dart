import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/features/admin/data/admin_service.dart';

class AdminTransactionsScreen extends StatelessWidget {
  const AdminTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AdminService();
    return Scaffold(
      appBar: AppBar(title: const Text('Admin — Transactions')),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.transactionsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No transactions yet'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final raw = docs[i].data();
              final d = (raw is Map<String, dynamic>)
                  ? Map<String, dynamic>.from(raw)
                  : <String, dynamic>{};
              final amount = d['amount'] ?? 0;
              final type = d['type'] ?? 'tx';
              final userId = d['userId'] ?? 'unknown';
              final created = (d['createdAt'] as Timestamp?)?.toDate();
              return ListTile(
                title: Text('$type • ₱${(amount / 100).toStringAsFixed(2)}'),
                subtitle: Text('user: $userId • ${d['meta'] ?? ''}'),
                trailing: Text(created != null ? '${created.toLocal()}' : ''),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
