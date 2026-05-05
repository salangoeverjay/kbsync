import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/admin/data/admin_service.dart';

// Content-only version for use in dashboard
class AdminTransactionsScreenContent extends StatefulWidget {
  const AdminTransactionsScreenContent({super.key});

  @override
  State<AdminTransactionsScreenContent> createState() =>
      _AdminTransactionsScreenContentState();
}

class _AdminTransactionsScreenContentState
    extends State<AdminTransactionsScreenContent> {
  final AdminService _service = AdminService();
  String _selectedStatus = 'pending';

  Future<void> _approveUser(String userId) async {
    try {
      await _service.approveUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User approved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to approve user: $e')));
    }
  }

  Future<void> _declineUser(String userId) async {
    try {
      await _service.disapproveUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User declined.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to decline user: $e')));
    }
  }

  String _normalizedStatus(Map<String, dynamic> data) {
    final value = (data['verificationStatus'] ?? data['status'] ?? 'pending')
        .toString()
        .trim()
        .toLowerCase();
    if (value == 'approved' || value == 'declined' || value == 'pending') {
      return value;
    }
    return 'pending';
  }

  String _titleForStatus(String status) {
    if (status == 'approved') return 'Approved users';
    if (status == 'declined') return 'Declined users';
    return 'Pending approvals';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.usersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        final mapped = docs.map((doc) {
          final raw = doc.data();
          final data = raw is Map<String, dynamic>
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};
          return {'id': doc.id, 'data': data};
        }).toList();

        final filtered = mapped.where((entry) {
          final status = _normalizedStatus(
            entry['data']! as Map<String, dynamic>,
          );
          return status == _selectedStatus;
        }).toList();

        final pendingCount = mapped.where((entry) {
          return _normalizedStatus(entry['data']! as Map<String, dynamic>) ==
              'pending';
        }).length;
        final approvedCount = mapped.where((entry) {
          return _normalizedStatus(entry['data']! as Map<String, dynamic>) ==
              'approved';
        }).length;
        final declinedCount = mapped.where((entry) {
          return _normalizedStatus(entry['data']! as Map<String, dynamic>) ==
              'declined';
        }).length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatusChip(
                          label: 'Pending ($pendingCount)',
                          selected: _selectedStatus == 'pending',
                          color: AppColors.orange,
                          onTap: () =>
                              setState(() => _selectedStatus = 'pending'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatusChip(
                          label: 'Approved ($approvedCount)',
                          selected: _selectedStatus == 'approved',
                          color: AppColors.green,
                          onTap: () =>
                              setState(() => _selectedStatus = 'approved'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatusChip(
                          label: 'Declined ($declinedCount)',
                          selected: _selectedStatus == 'declined',
                          color: const Color(0xFFDC2626),
                          onTap: () =>
                              setState(() => _selectedStatus = 'declined'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _titleForStatus(_selectedStatus),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No users found for this status'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final item = filtered[i];
                        final userId = item['id']! as String;
                        final d = item['data']! as Map<String, dynamic>;
                        final name =
                            (d['fullName'] ?? d['name'] ?? d['displayName'])
                                ?.toString()
                                .trim();
                        final email = (d['email'] ?? '').toString();
                        final role = (d['role'] ?? 'worker').toString();
                        final status = _normalizedStatus(d);

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (name == null || name.isEmpty)
                                    ? 'Unnamed user'
                                    : name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email.isEmpty ? 'No email' : email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mid,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _RoleBadge(role: role),
                                  const SizedBox(width: 8),
                                  _StatusBadge(status: status),
                                  const Spacer(),
                                  if (status == 'pending') ...[
                                    TextButton(
                                      onPressed: () => _declineUser(userId),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFDC2626,
                                        ),
                                      ),
                                      child: const Text('Decline'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _approveUser(userId),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Approve'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class AdminTransactionsScreen extends StatelessWidget {
  const AdminTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin — Approvals')),
      body: const AdminTransactionsScreenContent(),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Center(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? color : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final normalized = role.trim().toLowerCase();
    final bg = normalized == 'resident'
        ? AppColors.plum.withValues(alpha: 0.1)
        : AppColors.orange.withValues(alpha: 0.12);
    final fg = normalized == 'resident' ? AppColors.plum : AppColors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized.isEmpty ? 'user' : normalized,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color fg;
    if (status == 'approved') {
      fg = AppColors.green;
    } else if (status == 'declined') {
      fg = const Color(0xFFDC2626);
    } else {
      fg = AppColors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
