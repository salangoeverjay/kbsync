import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/constants.dart';
import 'package:kbsync/features/auth/data/firebase_auth_service.dart';
import 'package:kbsync/features/worker/data/worker_active_task_service.dart';
import 'package:kbsync/features/worker/data/worker_lockout_service.dart';
import 'package:kbsync/features/worker/data/worker_presence_service.dart';
import 'package:kbsync/features/worker/data/worker_task_feed_service.dart';
import 'package:kbsync/features/worker/presentation/widgets/active_task_banner.dart';
import 'package:kbsync/features/worker/presentation/widgets/worker_lockout_banner.dart';
import 'package:kbsync/core/widgets/kb_bottom_nav.dart';
import 'package:kbsync/core/widgets/kb_buttons.dart';
import 'package:kbsync/core/widgets/progress_ring.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  bool _online = true;
  final FirebaseAuthService _authService = FirebaseAuthService();
  final WorkerPresenceService _presenceService = WorkerPresenceService();
  final WorkerTaskFeedService _taskFeedService = WorkerTaskFeedService();
  final WorkerLockoutService _lockoutService = WorkerLockoutService();
  final WorkerActiveTaskService _activeTaskService = WorkerActiveTaskService();
  late final Future<String?> _fullNameFuture = _authService
      .getCurrentUserFullName();

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    unawaited(_presenceService.setOnline(_online));
  }

  @override
  void dispose() {
    unawaited(_presenceService.setOnline(false));
    unawaited(_presenceService.dispose());
    super.dispose();
  }

  Future<void> _toggleOnline() async {
    final next = !_online;
    setState(() => _online = next);
    await _presenceService.setOnline(next);
  }

  Stream<_WorkerDashboardProfile> _profileStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data() ?? const <String, dynamic>{};
          return _WorkerDashboardProfile.fromMap(data);
        });
  }

  Widget _buildDashboardContent({
    required _WorkerDashboardProfile profile,
    required List<WorkerOpenTask> openTasks,
    required WorkerLockoutState lockoutState,
    required List<WorkerActiveTask> activeTasks,
  }) {
    final highlightedTask = openTasks.isEmpty ? null : openTasks.first;
    final locked = lockoutState.isLocked();
    final activeTask = activeTasks.isEmpty ? null : activeTasks.first;

    void showLockoutSnack() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are temporarily locked out from accepting tasks.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          if (locked)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WorkerLockoutBanner(state: lockoutState),
            ),
          if (activeTask != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ActiveTaskBanner(
                task: activeTask,
                onCancel: () => _activeTaskService.cancelActiveTask(
                  taskId: activeTask.id,
                  ownerId: activeTask.ownerId,
                ),
              ),
            ),
          _TrustEarningsRow(profile: profile),
          const SizedBox(height: 20),
          _WalletCard(
            balance: profile.balance,
            trustBond: profile.trustBond,
            onOpenProfile: () =>
                Navigator.of(context).pushNamed(AppRoutes.profile),
          ),
          const SizedBox(height: 12),
          if (_online && highlightedTask != null) ...[
            Opacity(
              opacity: locked ? 0.5 : 1.0,
              child: _TaskAlertCard(
                task: highlightedTask,
                onTap: locked
                    ? showLockoutSnack
                    : () => Navigator.of(context).pushNamed(
                        AppRoutes.taskAvailable,
                        arguments: highlightedTask,
                      ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Opacity(
            opacity: locked ? 0.5 : 1.0,
            child: _BrowseTasksCard(
              availableCount: openTasks.length,
              onTap: locked
                  ? showLockoutSnack
                  : () =>
                        Navigator.of(context).pushNamed(AppRoutes.nearbyTasks),
            ),
          ),
          const SizedBox(height: 20),
          // Weekly earnings moved to wallet screen
          _RookieStatus(completedTasks: profile.completedTasks),
          const SizedBox(height: 20),
          _RecentTasksList(tasks: openTasks.take(3).toList(growable: false)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: KbBottomNav(
        active: KbNavTab.home,
        onTap: (tab) {
          if (tab == KbNavTab.home) return;
          final route = switch (tab) {
            KbNavTab.tasks => AppRoutes.nearbyTasks,
            KbNavTab.wallet => AppRoutes.wallet,
            KbNavTab.profile => AppRoutes.profile,
            KbNavTab.home => AppRoutes.workerDashboard,
          };
          Navigator.of(context).pushReplacementNamed(route);
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _WorkerHeader(
              online: _online,
              fullNameFuture: _fullNameFuture,
              onToggle: _toggleOnline,
              onOpenProfile: () =>
                  Navigator.of(context).pushNamed(AppRoutes.profile),
            ),
            Expanded(
              child: StreamBuilder<List<WorkerOpenTask>>(
                stream: _taskFeedService.watchOpenTasks(),
                builder: (context, tasksSnapshot) {
                  final openTasks =
                      tasksSnapshot.data ?? const <WorkerOpenTask>[];
                  final uid = _currentUserId;

                  if (uid == null) {
                    return _buildDashboardContent(
                      profile: _WorkerDashboardProfile.empty,
                      openTasks: openTasks,
                      lockoutState: WorkerLockoutState.empty,
                      activeTasks: const <WorkerActiveTask>[],
                    );
                  }

                  return StreamBuilder<List<WorkerActiveTask>>(
                    stream: _activeTaskService.watchActiveTasks(uid),
                    initialData: const <WorkerActiveTask>[],
                    builder: (context, activeSnapshot) {
                      final activeTasks =
                          activeSnapshot.data ?? const <WorkerActiveTask>[];
                      return StreamBuilder<WorkerLockoutState>(
                        stream: _lockoutService.watchLockout(uid),
                        initialData: WorkerLockoutState.empty,
                        builder: (context, lockoutSnapshot) {
                          final lockoutState =
                              lockoutSnapshot.data ?? WorkerLockoutState.empty;
                          return StreamBuilder<_WorkerDashboardProfile>(
                            stream: _profileStream(uid),
                            initialData: _WorkerDashboardProfile.empty,
                            builder: (context, profileSnapshot) {
                              final profile =
                                  profileSnapshot.data ??
                                  _WorkerDashboardProfile.empty;
                              return _buildDashboardContent(
                                profile: profile,
                                openTasks: openTasks,
                                lockoutState: lockoutState,
                                activeTasks: activeTasks,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerHeader extends StatelessWidget {
  final bool online;
  final Future<String?> fullNameFuture;
  final VoidCallback onToggle;
  final VoidCallback onOpenProfile;
  const _WorkerHeader({
    required this.online,
    required this.fullNameFuture,
    required this.onToggle,
    required this.onOpenProfile,
  });

  String _greetingForNow() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: onOpenProfile,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.grad,
                borderRadius: BorderRadius.circular(44 * 0.3),
              ),
              child: const Center(
                child: Text(
                  'J',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder<String?>(
              future: fullNameFuture,
              builder: (context, snapshot) {
                final fullName = snapshot.data?.trim();
                final displayName = (fullName == null || fullName.isEmpty)
                    ? 'User'
                    : fullName;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greetingForNow()} 👋',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.4,
                        color: AppColors.plum,
                      ),
                    ),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.4,
                        color: AppColors.plum,
                      ),
                    ),
                    const KbStatusTag.green('✓ Ka-Bayan Verified'),
                  ],
                );
              },
            ),
          ),
          Text(
            online ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: online ? AppColors.orange : AppColors.mid,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 48,
              height: 26,
              decoration: BoxDecoration(
                color: online ? AppColors.orange : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(13),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: online
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustEarningsRow extends StatelessWidget {
  final _WorkerDashboardProfile profile;

  const _TrustEarningsRow({required this.profile});

  String _formatPeso(double amount) {
    return amount % 1 == 0
        ? '₱${amount.toStringAsFixed(0)}'
        : '₱${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final trustScore = profile.trustScore.clamp(0, 100).round();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                ProgressRing(
                  percent: trustScore.toDouble(),
                  size: 90,
                  strokeWidth: 9,
                  fillColor: AppColors.plum,
                  trackColor: const Color(0x1A911B44),
                  child: Text(
                    '$trustScore',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: AppColors.plum,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Trust Score',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  profile.completedTasks > 0
                      ? '${profile.completedTasks} tasks completed'
                      : 'Start completing tasks to grow score',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.ink.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppColors.grad,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Earnings",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPeso(profile.todayEarnings),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      profile.todayEarnings > 0
                          ? 'Live from your account data'
                          : 'No earnings posted today yet',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
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
                      'Rating',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.ink.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      '${profile.rating.toStringAsFixed(1)}★',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: AppColors.orange,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${profile.completedTasks} tasks done',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.ink.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WalletCard extends StatelessWidget {
  final double balance;
  final double trustBond;
  final VoidCallback onOpenProfile;

  const _WalletCard({
    required this.balance,
    required this.trustBond,
    required this.onOpenProfile,
  });

  String _formatPeso(double amount) {
    return amount % 1 == 0
        ? '₱${amount.toStringAsFixed(0)}'
        : '₱${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ka-Bayan Wallet',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: onOpenProfile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orangeLt,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 13,
                            color: AppColors.orange,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Profile',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const KbStatusTag.green('Trust Bond Active'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: AppColors.grad,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Balance',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        _formatPeso(balance),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 90,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.orangeLt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trust Bond',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPeso(trustBond),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskAlertCard extends StatelessWidget {
  final WorkerOpenTask task;
  final VoidCallback onTap;
  const _TaskAlertCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.orange, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.orangeLt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('🔔', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New Task Available!',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.orange,
                    ),
                  ),
                  Text(
                    '${task.serviceFilterLabel} • ${task.total}',
                    style: TextStyle(fontSize: 12, color: AppColors.mid),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: AppColors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowseTasksCard extends StatelessWidget {
  final int availableCount;
  final VoidCallback onTap;
  const _BrowseTasksCard({required this.availableCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.plum.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                size: 22,
                color: AppColors.plum,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Browse Nearby Tasks',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.plum,
                    ),
                  ),
                  Text(
                    '$availableCount tasks available within ${(kNearbyRadiusMeters / 1000).toInt()}km',
                    style: TextStyle(fontSize: 12, color: AppColors.mid),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: AppColors.plum,
            ),
          ],
        ),
      ),
    );
  }
}

class _RookieStatus extends StatelessWidget {
  final int completedTasks;

  const _RookieStatus({required this.completedTasks});

  @override
  Widget build(BuildContext context) {
    final progress = (completedTasks / 5).clamp(0.0, 1.0);
    final tasksLeft = (5 - completedTasks).clamp(0, 5);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rookie Status',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              KbStatusTag.orange(
                tasksLeft == 0 ? 'Unlocked' : '$tasksLeft tasks left',
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: tasksLeft == 0
                  ? 'You already unlocked '
                  : 'Complete $tasksLeft more tasks to unlock ',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.ink.withValues(alpha: 0.5),
                height: 1.5,
              ),
              children: const [
                TextSpan(
                  text: 'Pabili (grocery)',
                  style: TextStyle(
                    color: AppColors.plum,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: ' requests and full Ka-Bayan benefits.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTasksList extends StatelessWidget {
  final List<WorkerOpenTask> tasks;

  const _RecentTasksList({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Tasks',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'History',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No tasks yet.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.ink.withValues(alpha: 0.55),
                ),
              ),
            ),
          ...tasks.asMap().entries.map(
            (e) => Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: e.key < tasks.length - 1
                    ? Border(bottom: BorderSide(color: AppColors.border))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.orangeLt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        e.value.icon,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.value.serviceFilterLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          '${e.value.ownerName} • ${e.value.timeLabel}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.ink.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    e.value.total,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerDashboardProfile {
  final double trustScore;
  final double todayEarnings;
  final double rating;
  final int completedTasks;
  final double balance;
  final double trustBond;

  const _WorkerDashboardProfile({
    required this.trustScore,
    required this.todayEarnings,
    required this.rating,
    required this.completedTasks,
    required this.balance,
    required this.trustBond,
  });

  static const empty = _WorkerDashboardProfile(
    trustScore: 0,
    todayEarnings: 0,
    rating: 0,
    completedTasks: 0,
    balance: 0,
    trustBond: 30,
  );

  factory _WorkerDashboardProfile.fromMap(Map<String, dynamic> data) {
    final completedTasks =
        _asInt(data['completedTasks']) ??
        _asInt(data['tasksCompleted']) ??
        _asInt(data['totalCompletedTasks']) ??
        0;

    final rating =
        _asDouble(data['rating']) ??
        _asDouble(data['averageRating']) ??
        _asDouble(data['workerRating']) ??
        0;

    final trustScore = _asDouble(data['trustScore']) ?? (rating * 20);

    return _WorkerDashboardProfile(
      trustScore: trustScore,
      todayEarnings: _asDouble(data['todayEarnings']) ?? 0,
      rating: rating,
      completedTasks: completedTasks,
      balance: _asDouble(data['walletBalance']) ?? 0,
      trustBond: _asDouble(data['trustBond']) ?? 30,
    );
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      return double.tryParse(normalized);
    }
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      final normalized = value.replaceAll(RegExp(r'[^0-9-]'), '');
      return int.tryParse(normalized);
    }
    return null;
  }
}
