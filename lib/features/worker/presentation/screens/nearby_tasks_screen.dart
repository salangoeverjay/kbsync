import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/constants.dart';
import 'package:kbsync/core/widgets/kb_bottom_nav.dart';
import 'package:kbsync/features/resident/data/resident_location_service.dart';
import 'package:kbsync/features/worker/data/worker_active_task_service.dart';
import 'package:kbsync/features/worker/data/worker_lockout_service.dart';
import 'package:kbsync/features/worker/data/worker_task_feed_service.dart';
import 'package:kbsync/features/worker/presentation/widgets/active_task_banner.dart';
import 'package:kbsync/features/worker/presentation/widgets/worker_lockout_banner.dart';
import 'package:latlong2/latlong.dart';

class NearbyTasksScreen extends StatefulWidget {
  const NearbyTasksScreen({super.key});

  @override
  State<NearbyTasksScreen> createState() => _NearbyTasksScreenState();
}

class _NearbyTasksScreenState extends State<NearbyTasksScreen> {
  final WorkerTaskFeedService _taskFeedService = WorkerTaskFeedService();
  final WorkerLockoutService _lockoutService = WorkerLockoutService();
  final WorkerActiveTaskService _activeTaskService = WorkerActiveTaskService();
  String _filter = 'All';
  bool _sortByDistance = true;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  static const _filters = ['All', 'Cleaning', 'Pabili', 'Laundry', 'Dishes'];

  List<WorkerOpenTask> _filteredTasks(List<WorkerOpenTask> tasks) {
    final filtered = _filter == 'All'
        ? tasks
        : tasks
              .where((task) => task.serviceFilterLabel == _filter)
              .toList(growable: false);

    final sorted = [...filtered];
    sorted.sort((a, b) {
      final aScore = _distanceSeed(a.id);
      final bScore = _distanceSeed(b.id);
      return _sortByDistance
          ? aScore.compareTo(bScore)
          : b.payout.compareTo(a.payout);
    });
    return sorted;
  }

  double _distanceSeed(String id) {
    final seed = id.codeUnits.fold<int>(0, (sum, code) => sum + code);
    final km = 0.4 + (seed % 16) / 10;
    return double.parse(km.toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: KbBottomNav(
        active: KbNavTab.tasks,
        onTap: (tab) {
          if (tab == KbNavTab.tasks) return;
          final route = switch (tab) {
            KbNavTab.home => AppRoutes.workerDashboard,
            KbNavTab.wallet => AppRoutes.wallet,
            KbNavTab.profile => AppRoutes.profile,
            KbNavTab.tasks => AppRoutes.nearbyTasks,
          };
          Navigator.of(context).pushReplacementNamed(route);
        },
      ),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<WorkerLockoutState>(
          stream: _currentUserId == null
              ? Stream<WorkerLockoutState>.value(WorkerLockoutState.empty)
              : _lockoutService.watchLockout(_currentUserId!),
          initialData: WorkerLockoutState.empty,
          builder: (context, lockoutSnap) {
            final lockoutState = lockoutSnap.data ?? WorkerLockoutState.empty;
            final locked = lockoutState.isLocked();
            return StreamBuilder<List<WorkerOpenTask>>(
              stream: _taskFeedService.watchOpenTasks(),
              builder: (context, snapshot) {
                final tasks = _filteredTasks(
                  snapshot.data ?? const <WorkerOpenTask>[],
                );

                void showLockoutSnack() {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'You are temporarily locked out from accepting tasks.',
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Color(0xFFB91C1C),
                    ),
                  );
                }

                return Column(
                  children: [
                    if (locked) WorkerLockoutBanner(state: lockoutState),
                    if (_currentUserId != null)
                      StreamBuilder<List<WorkerActiveTask>>(
                        stream: _activeTaskService.watchActiveTasks(
                          _currentUserId!,
                        ),
                        initialData: const <WorkerActiveTask>[],
                        builder: (context, activeSnap) {
                          final activeTasks =
                              activeSnap.data ?? const <WorkerActiveTask>[];
                          if (activeTasks.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final activeTask = activeTasks.first;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: ActiveTaskBanner(
                              task: activeTask,
                              onCancel: () =>
                                  _activeTaskService.cancelActiveTask(
                                    taskId: activeTask.id,
                                    ownerId: activeTask.ownerId,
                                  ),
                            ),
                          );
                        },
                      ),
                    _NearbyHeader(
                      count: tasks.length,
                      sortByDistance: _sortByDistance,
                      filter: _filter,
                      onToggleSort: () =>
                          setState(() => _sortByDistance = !_sortByDistance),
                      onFilterChanged: (f) => setState(() => _filter = f),
                    ),
                    _MapStrip(tasks: tasks),
                    Expanded(
                      child: tasks.isEmpty
                          ? const _EmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                16,
                              ),
                              itemCount: tasks.length,
                              itemBuilder: (ctx, i) {
                                final task = tasks[i];
                                return Opacity(
                                  opacity: locked ? 0.5 : 1.0,
                                  child: _TaskCard(
                                    task: task,
                                    distKm: _distanceSeed(task.id),
                                    onTap: locked
                                        ? showLockoutSnack
                                        : () => Navigator.of(ctx).pushNamed(
                                            AppRoutes.taskAvailable,
                                            arguments: task,
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NearbyHeader extends StatelessWidget {
  final int count;
  final bool sortByDistance;
  final String filter;
  final VoidCallback onToggleSort;
  final ValueChanged<String> onFilterChanged;

  const _NearbyHeader({
    required this.count,
    required this.sortByDistance,
    required this.filter,
    required this.onToggleSort,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nearby Tasks',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: -0.6,
                        color: AppColors.plum,
                      ),
                    ),
                    Text(
                      '$count tasks within ${(kNearbyRadiusMeters / 1000).toInt()}km',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onToggleSort,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.orangeLt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.swap_vert_rounded,
                        size: 14,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sortByDistance ? 'By Distance' : 'By Payout',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _NearbyTasksScreenState._filters.map((f) {
                final on = filter == f;
                final emoji = switch (f) {
                  'Cleaning' => '🧹 ',
                  'Pabili' => '🛒 ',
                  'Laundry' => '🧺 ',
                  'Dishes' => '🍽️ ',
                  _ => '',
                };
                return GestureDetector(
                  onTap: () => onFilterChanged(f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 7),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: on ? AppColors.grad : null,
                      color: on ? null : AppColors.plum.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$emoji$f',
                      style: TextStyle(
                        color: on ? Colors.white : AppColors.plum,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapStrip extends StatelessWidget {
  final List<WorkerOpenTask> tasks;

  const _MapStrip({required this.tasks});

  static const _locationService = ResidentLocationService();

  LatLng _offsetFromCenter(LatLng center, String taskId) {
    final seed = taskId.codeUnits.fold<int>(0, (sum, code) => sum + code);
    final radiusMeters = 250 + (seed % 1550); // 250m..1800m
    final angleDeg = (seed * 37) % 360;
    final angle = angleDeg * math.pi / 180;

    const earthRadius = 6378137.0;
    final northMeters = radiusMeters * math.sin(angle);
    final eastMeters = radiusMeters * math.cos(angle);
    final dLat = northMeters / earthRadius;
    final dLng =
        eastMeters / (earthRadius * math.cos(center.latitude * math.pi / 180));

    return LatLng(
      center.latitude + dLat * 180 / math.pi,
      center.longitude + dLng * 180 / math.pi,
    );
  }

  String _residentInitial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'R';
    return trimmed.characters.first.toUpperCase();
  }

  List<({String ownerId, String ownerName, LatLng point})> _residentPins(
    LatLng center,
    List<WorkerOpenTask> tasks,
  ) {
    final uniqueByOwner = <String, WorkerOpenTask>{};
    for (final task in tasks) {
      if (!uniqueByOwner.containsKey(task.ownerId)) {
        uniqueByOwner[task.ownerId] = task;
      }
    }

    return uniqueByOwner.values
        .map(
          (task) => (
            ownerId: task.ownerId,
            ownerName: task.ownerName,
            point: _offsetFromCenter(center, task.ownerId),
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visibleTasks = tasks.take(12).toList(growable: false);

    return SizedBox(
      height: 130,
      child: StreamBuilder<LatLng>(
        stream: _locationService.locationStream(),
        initialData: ResidentLocationService.fallbackLocation,
        builder: (context, snapshot) {
          final center =
              snapshot.data ?? ResidentLocationService.fallbackLocation;
          final residentPins = _residentPins(center, visibleTasks);
          return Stack(
            children: [
              FlutterMap(
                key: ValueKey<String>(
                  '${center.latitude.toStringAsFixed(6)}:${center.longitude.toStringAsFixed(6)}:${visibleTasks.length}',
                ),
                options: MapOptions(initialCenter: center, initialZoom: 15.2),
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
                        radius: kNearbyRadiusMeters,
                        useRadiusInMeter: true,
                        color: AppColors.orange.withValues(alpha: 0.06),
                        borderColor: AppColors.orange.withValues(alpha: 0.8),
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
                            color: AppColors.plum,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ),
                      ...residentPins.map((resident) {
                        return Marker(
                          point: resident.point,
                          width: 32,
                          height: 32,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _residentInitial(resident.ownerName),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 8,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'YOU ARE HERE',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              if (tasks.isNotEmpty)
                Positioned(
                  bottom: 8,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${residentPins.length} RESIDENTS',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final WorkerOpenTask task;
  final double distKm;
  final VoidCallback onTap;
  const _TaskCard({
    required this.task,
    required this.distKm,
    required this.onTap,
  });

  Color get _complexityColor => switch (task.complexity) {
    'Light' => AppColors.green,
    'Moderate' => AppColors.orange,
    'Heavy' => AppColors.plum,
    _ => AppColors.mid,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.orangeLt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      task.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              task.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: -0.3,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (task.isRush) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.orangeLt,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'RUSH',
                                style: TextStyle(
                                  color: AppColors.orange,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text.rich(
                        TextSpan(
                          text: '${task.areaLabel} • Client: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.ink.withValues(alpha: 0.5),
                          ),
                          children: [
                            TextSpan(
                              text: task.ownerName,
                              style: const TextStyle(
                                color: AppColors.plum,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (task.requiresMerchantQrPayment) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.plum.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Direct merchant payment via QR',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.plum,
                            ),
                          ),
                        ),
                      ],
                      if (task.serviceFilterLabel == 'Pabili' &&
                          task.groceryListLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Buy list: ${task.groceryListLabel}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink.withValues(alpha: 0.75),
                          ),
                        ),
                      ] else if (task.serviceFilterLabel == 'Pabili' &&
                          task.groceryBudgetLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Budget: ${task.groceryBudgetLabel}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink.withValues(alpha: 0.75),
                          ),
                        ),
                      ] else if (task.notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${task.payout}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: AppColors.green,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      task.timeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.ink.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _TagPill(
                      icon: Icons.location_on_rounded,
                      text: '${distKm}km',
                      bg: Colors.black.withValues(alpha: 0.04),
                      fg: AppColors.mid,
                    ),
                    const SizedBox(width: 6),
                    _TagPill(
                      text: task.complexity,
                      bg: _complexityColor.withValues(alpha: 0.12),
                      fg: _complexityColor,
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.grad,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.plum.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color bg, fg;
  const _TagPill({
    this.icon,
    required this.text,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔍', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text(
            'No tasks found',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.mid,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Try a different filter',
            style: TextStyle(fontSize: 12, color: AppColors.mid),
          ),
        ],
      ),
    );
  }
}
