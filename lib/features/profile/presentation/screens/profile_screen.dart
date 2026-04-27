import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/widgets/kb_bottom_nav.dart';
import 'package:kbsync/features/auth/data/firebase_auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  String? _userRole;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final verificationState = await _authService.getVerificationState(
        uid: userId,
      );
      if (!mounted) return;
      setState(() {
        _userRole = verificationState?.role;
      });
    } catch (_) {}
  }

  Future<String> _resolveUserRole() async {
    final cached = _userRole;
    if (cached != null && cached.isNotEmpty) return cached;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return 'resident';

    try {
      final verificationState = await _authService.getVerificationState(
        uid: userId,
      );
      final role = verificationState?.role?.trim().toLowerCase();
      if (role != null && role.isNotEmpty) {
        if (mounted) {
          setState(() {
            _userRole = role;
          });
        }
        return role;
      }
    } catch (_) {}

    return 'resident';
  }

  Future<void> _onNavTap(KbNavTab tab) async {
    if (tab == KbNavTab.profile) return;

    final role = await _resolveUserRole();
    if (!mounted) return;

    if (tab == KbNavTab.home) {
      final homeRoute = role == 'resident'
          ? AppRoutes.residentDashboard
          : AppRoutes.workerDashboard;
      Navigator.of(context).pushReplacementNamed(homeRoute);
    } else if (tab == KbNavTab.tasks) {
      final tasksRoute = role == 'resident'
          ? AppRoutes.createTask
          : AppRoutes.nearbyTasks;
      Navigator.of(context).pushReplacementNamed(tasksRoute);
    } else if (tab == KbNavTab.wallet) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.wallet);
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to log out. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  Future<_ProfileViewModel?> _loadProfile() async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final user = auth.currentUser;
    if (user == null) return null;

    final snapshot = await firestore.collection('users').doc(user.uid).get();
    final data = snapshot.data() ?? <String, dynamic>{};

    final fullName = _pickFirstNonEmpty([
      data['fullName'] as String?,
      user.displayName,
    ]);

    final email = _pickFirstNonEmpty([data['email'] as String?, user.email]);

    final phone = _pickFirstNonEmpty([
      data['phone'] as String?,
      data['phoneNumber'] as String?,
      user.phoneNumber,
    ]);

    final role = _pickFirstNonEmpty([data['role'] as String?]);

    final verificationStatus = _pickFirstNonEmpty([
      data['verificationStatus'] as String?,
      (data['isVerified'] == true) ? 'approved' : null,
    ]);

    final createdAtRaw = data['createdAt'];
    DateTime? createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    }

    return _ProfileViewModel(
      fullName: fullName ?? 'User',
      role: role ?? 'resident',
      verificationStatus: verificationStatus ?? 'pending',
      emailMasked: _maskEmail(email),
      phoneMasked: _maskPhone(phone),
      uidMasked: _maskId(user.uid),
      createdAt: createdAt,
    );
  }

  static String? _pickFirstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String _maskEmail(String? email) {
    if (email == null || email.isEmpty || !email.contains('@')) {
      return 'Not provided';
    }

    final parts = email.split('@');
    final local = parts.first;
    final domain = parts.last;
    if (local.length <= 2) {
      final first = local.isEmpty ? '*' : local.substring(0, 1);
      return '$first***@$domain';
    }

    final start = local.substring(0, 2);
    return '$start***@$domain';
  }

  static String _maskPhone(String? phone) {
    if (phone == null || phone.isEmpty) return 'Not provided';

    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4) return '***';

    final tail = digits.substring(digits.length - 4);
    return '***-***-$tail';
  }

  static String _maskId(String value) {
    if (value.isEmpty) return 'Not available';
    if (value.length <= 6) return '***';

    final start = value.substring(0, 3);
    final end = value.substring(value.length - 3);
    return '$start***$end';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[date.month - 1];
    return '$month ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: KbBottomNav(
        active: KbNavTab.profile,
        onTap: (tab) => _onNavTap(tab),
      ),
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_ProfileViewModel?>(
          future: _loadProfile(),
          builder: (context, snapshot) {
            final profile = snapshot.data;

            return Column(
              children: [
                _ProfileHeader(onBack: () => Navigator.of(context).pop()),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: profile == null
                        ? const _EmptyProfileState()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _IdentityCard(profile: profile),
                              const SizedBox(height: 14),
                              _InfoCard(
                                title: 'Public Information',
                                rows: [
                                  ('Full Name', profile.fullName),
                                  ('Role', profile.role.toUpperCase()),
                                  (
                                    'Verification',
                                    profile.verificationStatus.toUpperCase(),
                                  ),
                                  (
                                    'Joined',
                                    profile.createdAt == null
                                        ? 'Unknown'
                                        : _formatDate(profile.createdAt!),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _InfoCard(
                                title: 'Confidential (Masked)',
                                rows: [
                                  ('Email', profile.emailMasked),
                                  ('Phone', profile.phoneMasked),
                                  ('User ID', profile.uidMasked),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoggingOut ? null : _logout,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: const BorderSide(
                                      color: AppColors.plum,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: _isLoggingOut
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.logout_rounded),
                                  label: Text(
                                    _isLoggingOut ? 'Logging out...' : 'Logout',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _ProfileHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.plum,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'My Profile',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final _ProfileViewModel profile;

  const _IdentityCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final initial = profile.fullName.trim().isEmpty
        ? 'U'
        : profile.fullName.trim().substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.grad,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile.role.toUpperCase()} • ${profile.verificationStatus.toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: AppColors.ink.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;

  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: index < rows.length - 1
                    ? Border(bottom: BorderSide(color: AppColors.border))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    row.$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink.withValues(alpha: 0.55),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.plum,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _EmptyProfileState extends StatelessWidget {
  const _EmptyProfileState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Text(
          'No signed-in user profile available.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.ink.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _ProfileViewModel {
  final String fullName;
  final String role;
  final String verificationStatus;
  final String emailMasked;
  final String phoneMasked;
  final String uidMasked;
  final DateTime? createdAt;

  const _ProfileViewModel({
    required this.fullName,
    required this.role,
    required this.verificationStatus,
    required this.emailMasked,
    required this.phoneMasked,
    required this.uidMasked,
    this.createdAt,
  });
}
