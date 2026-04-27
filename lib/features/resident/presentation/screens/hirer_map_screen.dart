import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/features/resident/data/nearby_worker_service.dart';
import 'package:kbsync/features/resident/data/resident_location_service.dart';
import 'package:kbsync/core/widgets/kb_bottom_nav.dart';
import 'package:kbsync/core/widgets/kb_buttons.dart';
import 'package:kbsync/core/widgets/progress_ring.dart';
import 'package:latlong2/latlong.dart';

class HirerMapScreen extends StatelessWidget {
  const HirerMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: KbBottomNav(
        active: KbNavTab.home,
        onTap: (tab) {
          if (tab == KbNavTab.tasks)
            Navigator.of(context).pushNamed(AppRoutes.createTask);
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Map background
            Positioned.fill(child: _MapBackground()),
            // Floating search bar
            Positioned(top: 8, left: 20, right: 20, child: _SearchBar()),
            // Bottom sheet
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _TaskBottomSheet(
                onNewTask: () =>
                    Navigator.of(context).pushNamed(AppRoutes.createTask),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBackground extends StatelessWidget {
  static const _locationService = ResidentLocationService();
  static final _workerService = NearbyWorkerService();
  static const _distance = Distance();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LatLng>(
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
                          2000,
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
                          radius: 200,
                          useRadiusInMeter: true,
                          color: AppColors.orange.withValues(alpha: 0.08),
                          borderColor: AppColors.orange.withValues(alpha: 0.7),
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
                            width: 32,
                            height: 32,
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
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  '👤',
                                  style: TextStyle(fontSize: 14),
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
              ],
            );
          },
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Search nearby workers...',
              style: TextStyle(
                fontFamily: 'PublicSans',
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          Icon(Icons.tune_rounded, size: 16, color: AppColors.green),
        ],
      ),
    );
  }
}

class _TaskBottomSheet extends StatelessWidget {
  final VoidCallback onNewTask;
  const _TaskBottomSheet({required this.onNewTask});
  static const _locationService = ResidentLocationService();
  static final _workerService = NearbyWorkerService();
  static const _distance = Distance();

  String _initialForName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'W';
    return trimmed.characters.first.toUpperCase();
  }

  String _distanceLabel(double meters) {
    if (meters < 1000) {
      return ' • ${meters.round()} m away';
    }

    final km = meters / 1000;
    return ' • ${km.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          // Worker info
          StreamBuilder<LatLng>(
            stream: _locationService.locationStream(),
            initialData: ResidentLocationService.fallbackLocation,
            builder: (context, locationSnapshot) {
              final center =
                  locationSnapshot.data ??
                  ResidentLocationService.fallbackLocation;

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
                                2000,
                          )
                          .toList(growable: false);

                  NearbyWorkerMarker? nearest;
                  double nearestMeters = 0;
                  for (final worker in workers) {
                    final meters = _distance.as(
                      LengthUnit.Meter,
                      center,
                      worker.position,
                    );
                    if (nearest == null || meters < nearestMeters) {
                      nearest = worker;
                      nearestMeters = meters;
                    }
                  }

                  final workerName = nearest?.name ?? 'Waiting for worker';
                  final distanceText = nearest == null
                      ? ' • no nearby worker yet'
                      : _distanceLabel(nearestMeters);

                  return Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppColors.grad,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            _initialForName(workerName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
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
                              workerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                letterSpacing: -0.4,
                                color: AppColors.ink,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 11,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '4.7',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.ink,
                                  ),
                                ),
                                Text(
                                  distanceText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.ink.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const KbStatusTag.green('VERIFIED'),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          // Scan banner
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            decoration: BoxDecoration(
              color: AppColors.orangeLt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🔍 Entrance Face Scan in Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.orange,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Worker is at your doorstep. Session begins once Face Scan is 100% matched.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.orange.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Details grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 3.5,
            children: [
              _DetailCell('Task ID', 'KB-4082790'),
              _DetailCell('Service', 'House Cleaning'),
              _DetailCell('Mode', 'RUSH'),
              _DetailCell('Arrived', '09:00 AM'),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Payment',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.ink.withValues(alpha: 0.5),
                    ),
                  ),
                  const Text(
                    '₱230',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: AppColors.plum,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Base ₱180 + Rush ₱50',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.ink.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onNewTask,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.grad,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '+ New Task',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailCell extends StatelessWidget {
  final String label, value;
  const _DetailCell(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.ink.withValues(alpha: 0.5),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.plum,
            ),
          ),
        ],
      ),
    );
  }
}
