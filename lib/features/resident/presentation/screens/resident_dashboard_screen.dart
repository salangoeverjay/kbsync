import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/constants.dart';
import 'package:kbsync/features/auth/data/firebase_auth_service.dart';
import 'package:kbsync/features/resident/data/resident_location_service.dart';
import 'package:kbsync/features/resident/data/nearby_worker_service.dart';
import 'package:kbsync/features/resident/data/resident_task_service.dart';
import 'package:kbsync/features/resident/presentation/widgets/resident_task_review_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kbsync/core/widgets/kb_bottom_nav.dart';
import 'package:kbsync/core/widgets/kb_buttons.dart';
import 'package:latlong2/latlong.dart';

class ResidentDashboardScreen extends StatefulWidget {
  const ResidentDashboardScreen({super.key});

  @override
  State<ResidentDashboardScreen> createState() =>
      _ResidentDashboardScreenState();
}

class _ResidentDashboardScreenState extends State<ResidentDashboardScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final ResidentTaskService _taskService = ResidentTaskService();
  late final Future<String?> _fullNameFuture = _authService
      .getCurrentUserFullName();

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _openCreateTask([String? service]) async {
    if (service == null) {
      await Navigator.of(context).pushNamed(AppRoutes.createTask);
    } else {
      await Navigator.of(
        context,
      ).pushNamed(AppRoutes.createTask, arguments: {'service': service});
    }
  }

  Future<bool> _confirmDeleteTask(ResidentTaskRecord task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel this task?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: AppColors.ink,
            letterSpacing: -0.3,
          ),
        ),
        content: Text(
          '“${task.title}” will be removed from your active tasks. This cannot be undone.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.ink.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Keep task',
              style: TextStyle(
                color: AppColors.plum,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteTask(ResidentTaskRecord task) async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      await _taskService.deleteTask(uid: uid, taskId: task.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancelled “${task.title}”.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.plum,
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not cancel task: $err')));
    }
  }

  Future<void> _reviewTask(ResidentTaskRecord task) async {
    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResidentTaskReviewSheet(task: task),
    );

    if (!mounted || approved == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approved
              ? 'Payment released to ${task.worker}. '
              : 'Task declined. No payment was sent.',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: approved ? AppColors.green : const Color(0xFFDC2626),
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
            KbNavTab.tasks => AppRoutes.createTask,
            KbNavTab.wallet => AppRoutes.wallet,
            KbNavTab.profile => AppRoutes.profile,
            KbNavTab.home => AppRoutes.residentDashboard,
          };
          Navigator.of(context).pushReplacementNamed(route);
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _DashHeader(
              fullNameFuture: _fullNameFuture,
              onCreateTask: _openCreateTask,
              onOpenProfile: () =>
                  Navigator.of(context).pushNamed(AppRoutes.profile),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StreamBuilder<List<ResidentTaskRecord>>(
                      stream: _currentUserId == null
                          ? Stream<List<ResidentTaskRecord>>.value(
                              const <ResidentTaskRecord>[],
                            )
                          : _taskService.watchActiveTasks(_currentUserId!),
                      builder: (context, snapshot) {
                        final tasks =
                            snapshot.data ?? const <ResidentTaskRecord>[];
                        final spending = _MonthlySpendingSummary.fromTasks(
                          tasks,
                        );

                        final hirableWorkers = tasks
                            .where((task) => task.worker != 'Awaiting worker')
                            .map((task) => task.worker)
                            .toSet();

                        final ratedTasks = tasks
                            .where((task) => task.rating != null)
                            .toList();
                        final avgRating = ratedTasks.isEmpty
                            ? 0.0
                            : ratedTasks.fold(
                                    0.0,
                                    (sum, task) => sum + (task.rating ?? 0),
                                  ) /
                                  ratedTasks.length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _StatsGrid(
                              activeTaskCount: tasks.length,
                              monthlySpending: spending.total,
                              hirableWorkersCount: hirableWorkers.length,
                              avgRating: avgRating,
                            ),
                            const SizedBox(height: 20),
                            _QuickActionsSection(
                              onTap: (s) => _openCreateTask(s),
                            ),
                            const SizedBox(height: 20),
                            _ActiveTasksSection(
                              tasks: tasks,
                              onTap: () => Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.hirerMap),
                              onReviewTask: _reviewTask,
                              onConfirmDelete: _confirmDeleteTask,
                              onDelete: _deleteTask,
                            ),
                            const SizedBox(height: 20),
                            _NearbyWorkersSection(
                              onOpen: () => Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.hirerMap),
                            ),
                            const SizedBox(height: 20),
                            _SpendingSection(summary: spending),
                            const SizedBox(height: 20),
                            _TaskHistorySection(tasks: tasks),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashHeader extends StatelessWidget {
  final Future<String?> fullNameFuture;
  final VoidCallback onCreateTask;
  final VoidCallback onOpenProfile;
  const _DashHeader({
    required this.fullNameFuture,
    required this.onCreateTask,
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
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(
        children: [
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -0.6,
                        color: AppColors.plum,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          _IconCircle(
            icon: Icons.add_rounded,
            bg: AppColors.orange,
            fg: Colors.white,
            onTap: onCreateTask,
          ),
          const SizedBox(width: 10),
          _IconCircle(
            icon: Icons.person_rounded,
            bg: AppColors.orangeLt,
            fg: AppColors.orange,
            onTap: onOpenProfile,
          ),
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  final IconData icon;
  final Color bg, fg;
  final VoidCallback onTap;
  const _IconCircle({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: fg),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int activeTaskCount;
  final double monthlySpending;
  final int hirableWorkersCount;
  final double avgRating;

  const _StatsGrid({
    required this.activeTaskCount,
    required this.monthlySpending,
    required this.hirableWorkersCount,
    required this.avgRating,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      (
        label: 'Active Tasks',
        val: '$activeTaskCount',
        icon: Icons.grid_view_rounded,
        bg: AppColors.plum,
      ),
      (
        label: 'This Month',
        val: _formatCurrency(monthlySpending),
        icon: Icons.account_balance_wallet_rounded,
        bg: AppColors.orange,
      ),
      (
        label: 'Workers Hired',
        val: '$hirableWorkersCount',
        icon: Icons.person_rounded,
        bg: const Color(0xFF0891B2),
      ),
      (
        label: 'Avg Rating',
        val: avgRating > 0 ? '${avgRating.toStringAsFixed(1)}★' : '–',
        icon: Icons.star_rounded,
        bg: const Color(0xFF059669),
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: stats
          .map(
            (s) =>
                _StatCard(label: s.label, val: s.val, icon: s.icon, bg: s.bg),
          )
          .toList(),
    );
  }
}

class _MonthlySpendingSummary {
  static const _displayOrder = <String>[
    'Cleaning',
    'Grocery',
    'Laundry',
    'Dishes',
  ];

  final double total;
  final Map<String, double> totalsByService;

  const _MonthlySpendingSummary({
    required this.total,
    required this.totalsByService,
  });

  factory _MonthlySpendingSummary.fromTasks(List<ResidentTaskRecord> tasks) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final totalsByService = <String, double>{
      for (final service in _displayOrder) service: 0,
    };

    double total = 0;

    for (final task in tasks) {
      final referenceDate = task.paymentReleasedAt ?? task.createdAt;
      if (referenceDate.isBefore(startOfMonth)) continue;

      final normalizedService = _normalizeService(task.service);
      final amount = task.totalAmount;
      total += amount;
      totalsByService[normalizedService] =
          (totalsByService[normalizedService] ?? 0) + amount;
    }

    return _MonthlySpendingSummary(
      total: total,
      totalsByService: totalsByService,
    );
  }

  static String _normalizeService(String service) {
    final value = service.trim().toLowerCase();
    if (value == 'grocery') return 'Grocery';
    if (value == 'laundry') return 'Laundry';
    if (value == 'dishes') return 'Dishes';
    return 'Cleaning';
  }
}

class _StatCard extends StatelessWidget {
  final String label, val;
  final IconData icon;
  final Color bg;
  const _StatCard({
    required this.label,
    required this.val,
    required this.icon,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: bg),
          ),
          const Spacer(),
          Text(
            val,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.ink.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  final void Function(String service) onTap;
  const _QuickActionsSection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        emoji: '🧹',
        label: 'Cleaning',
        service: 'Cleaning',
        color: AppColors.orange,
      ),
      (
        emoji: '🛒',
        label: 'Pabili',
        service: 'Grocery',
        color: const Color(0xFF0891B2),
      ),
      (
        emoji: '🧺',
        label: 'Laundry',
        service: 'Laundry',
        color: const Color(0xFF7C3AED),
      ),
      (
        emoji: '🍽️',
        label: 'Dishes',
        service: 'Dishes',
        color: const Color(0xFF059669),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 10),
        Row(
          children: actions
              .map(
                (a) => Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(a.service),
                    child: Container(
                      margin: EdgeInsets.only(
                        right: actions.last.label == a.label ? 0 : 8,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: a.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                a.emoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            a.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: AppColors.ink,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ActiveTasksSection extends StatefulWidget {
  final List<ResidentTaskRecord> tasks;
  final VoidCallback onTap;
  final Future<void> Function(ResidentTaskRecord task) onReviewTask;
  final Future<bool> Function(ResidentTaskRecord task) onConfirmDelete;
  final Future<void> Function(ResidentTaskRecord task) onDelete;

  const _ActiveTasksSection({
    required this.tasks,
    required this.onTap,
    required this.onReviewTask,
    required this.onConfirmDelete,
    required this.onDelete,
  });

  @override
  State<_ActiveTasksSection> createState() => _ActiveTasksSectionState();
}

class _ActiveTasksSectionState extends State<_ActiveTasksSection> {
  static const int _collapsedCount = 5;
  bool _expanded = false;

  bool _canDelete(ResidentTaskRecord t) =>
      t.statusLabel.toLowerCase() == 'open';

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final visible = _expanded
        ? widget.tasks
        : widget.tasks.take(_collapsedCount).toList();
    final canToggle = widget.tasks.length > _collapsedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Active Tasks',
          linkText: _expanded ? 'Show less' : 'View all',
          onLink: canToggle ? _toggleExpanded : null,
        ),
        const SizedBox(height: 10),
        if (widget.tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'No active tasks yet',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.ink.withValues(alpha: 0.5),
              ),
            ),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: Column(
            children: visible.map((t) {
              final status = t.statusLabel.trim().toLowerCase();
              final card = GestureDetector(
                onTap: status == 'completed'
                    ? () => widget.onReviewTask(t)
                    : widget.onTap,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
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
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.orangeLt,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            t.icon,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                            ),
                            Text.rich(
                              TextSpan(
                                text: 'Worker: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.ink.withValues(alpha: 0.5),
                                ),
                                children: [
                                  TextSpan(
                                    text: t.worker,
                                    style: const TextStyle(
                                      color: AppColors.plum,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          status == 'declined'
                              ? KbStatusTag.red(t.statusLabel)
                              : status == 'approved'
                              ? KbStatusTag.green(t.statusLabel)
                              : t.isOrange
                              ? KbStatusTag.orange(t.statusLabel)
                              : KbStatusTag.green(t.statusLabel),
                          const SizedBox(height: 4),
                          Text(
                            t.time,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.ink.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );

              if (!_canDelete(t)) return card;

              return Dismissible(
                key: ValueKey('active-task-${t.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                confirmDismiss: (_) => widget.onConfirmDelete(t),
                onDismissed: (_) => widget.onDelete(t),
                child: card,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _NearbyWorkersSection extends StatelessWidget {
  final VoidCallback onOpen;
  const _NearbyWorkersSection({required this.onOpen});
  static const _locationService = ResidentLocationService();
  static final _workerService = NearbyWorkerService();
  static const _distance = Distance();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Nearby Workers',
          linkText: 'Open Map',
          onLink: onOpen,
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onOpen,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 140,
              child: StreamBuilder<LatLng>(
                stream: _locationService.locationStream(),
                initialData: ResidentLocationService.fallbackLocation,
                builder: (context, snapshot) {
                  final center =
                      snapshot.data ?? ResidentLocationService.fallbackLocation;
                  return StreamBuilder<List<NearbyWorkerMarker>>(
                    stream: _workerService.watchAvailableWorkers(),
                    initialData: const <NearbyWorkerMarker>[],
                    builder: (context, workerSnapshot) {
                      final workers =
                          (workerSnapshot.data ?? const <NearbyWorkerMarker>[])
                              .where(
                                (worker) =>
                                    _distance.as(
                                      LengthUnit.Meter,
                                      center,
                                      worker.position,
                                    ) <=
                                    kNearbyRadiusMeters,
                              )
                              .toList(growable: false);

                      return Stack(
                        children: [
                          FlutterMap(
                            key: ValueKey<String>(
                              '${center.latitude.toStringAsFixed(6)}:${center.longitude.toStringAsFixed(6)}:${workers.length}',
                            ),
                            options: MapOptions(
                              initialCenter: center,
                              initialZoom: 15.5,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.kbsync',
                              ),
                              CircleLayer(
                                circles: [
                                  CircleMarker(
                                    point: center,
                                    radius: kMapCircleRadiusMeters,
                                    useRadiusInMeter: true,
                                    color: AppColors.orange.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderColor: AppColors.orange.withValues(
                                      alpha: 0.7,
                                    ),
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: center,
                                    width: 18,
                                    height: 18,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.orange,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  ...workers.map(
                                    (worker) => Marker(
                                      point: worker.position,
                                      width: 28,
                                      height: 28,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFC6E62),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.25,
                                              ),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '👤',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                24,
                                14,
                                10,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.4),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${workers.length} workers available nearby',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${(kNearbyRadiusMeters / 1000).toInt()}km radius →',
                                    style: TextStyle(
                                      color: AppColors.orange,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpendingSection extends StatelessWidget {
  final _MonthlySpendingSummary summary;

  const _SpendingSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final safeTotal = summary.total <= 0 ? 1.0 : summary.total;
    final items = [
      (
        label: 'House Cleaning',
        amount: summary.totalsByService['Cleaning'] ?? 0,
        color: AppColors.plum,
      ),
      (
        label: 'Pabili / Grocery',
        amount: summary.totalsByService['Grocery'] ?? 0,
        color: AppColors.orange,
      ),
      (
        label: 'Laundry',
        amount: summary.totalsByService['Laundry'] ?? 0,
        color: const Color(0xFF0891B2),
      ),
      (
        label: 'Dishes',
        amount: summary.totalsByService['Dishes'] ?? 0,
        color: const Color(0xFF059669),
      ),
    ];
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
          const _SectionHeader(title: 'Spending This Month'),
          const SizedBox(height: 10),
          ...items.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        _formatCurrency(s.amount),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.plum,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (s.amount / safeTotal).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.black.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(s.color),
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

String _formatCurrency(double amount) {
  final rounded = amount.round();
  final digits = rounded.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final indexFromRight = digits.length - i;
    buffer.write(digits[i]);
    if (indexFromRight > 1 && indexFromRight % 3 == 1) {
      buffer.write(',');
    }
  }

  if (rounded <= 0) {
    return '₱0';
  }

  return '₱$buffer';
}

class _TaskHistorySection extends StatelessWidget {
  final List<ResidentTaskRecord> tasks;

  const _TaskHistorySection({required this.tasks});

  static const _monthShortNames = <String>[
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

  String _dateLabel(DateTime date) {
    final month = _monthShortNames[date.month - 1];
    return '$month ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final history = [...tasks]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recent = history.take(3).toList(growable: false);

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
        children: [
          _SectionHeader(
            title: 'Task History',
            linkText: 'See all',
            onLink: () {},
          ),
          const SizedBox(height: 4),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No task history yet',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.ink.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ...recent.asMap().entries.map(
            (e) => Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: e.key < recent.length - 1
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
                          e.value.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          '${e.value.worker} • ${_dateLabel(e.value.createdAt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.ink.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(e.value.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.plum,
                        ),
                      ),
                      Text(
                        e.value.statusLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: e.value.isOrange
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF059669),
                        ),
                      ),
                    ],
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? linkText;
  final VoidCallback? onLink;
  const _SectionHeader({required this.title, this.linkText, this.onLink});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: AppColors.ink,
            letterSpacing: -0.3,
          ),
        ),
        if (linkText != null)
          GestureDetector(
            onTap: onLink,
            child: Text(
              linkText!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.orange,
              ),
            ),
          ),
      ],
    );
  }
}
