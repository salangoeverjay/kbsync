import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/features/admin/data/admin_service.dart';

class AdminWalletScreen extends StatelessWidget {
  const AdminWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AdminService();
    return Scaffold(
      appBar: AppBar(title: const Text('Admin — Platform Wallet')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<DocumentSnapshot>(
          stream: service.platformAccountStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final doc = snapshot.data!;
            if (!doc.exists) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('No platform account found.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      await service.ensureDefaultPlatformAccount();
                    },
                    child: const Text('Create default platform account'),
                  ),
                ],
              );
            }
            final raw = doc.data();
            final data = (raw is Map<String, dynamic>)
                ? Map<String, dynamic>.from(raw)
                : <String, dynamic>{};
            final balance = data['balance'] ?? 0;
            final currency = data['currency'] ?? 'PHP';
            final created = (data['createdAt'] as Timestamp?)?.toDate();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balance: ₱${(balance / 100).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('Currency: $currency'),
                if (created != null) ...[
                  const SizedBox(height: 8),
                  Text('Created: ${created.toLocal()}'),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await service.ensureDefaultPlatformAccount();
                  },
                  child: const Text('Ensure default account exists'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
