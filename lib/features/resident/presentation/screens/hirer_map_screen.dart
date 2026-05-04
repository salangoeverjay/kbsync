import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:kbsync/core/routing/app_routes.dart';
import 'package:kbsync/core/theme/app_colors.dart';
import 'package:kbsync/core/constants.dart';
import 'package:kbsync/features/resident/data/nearby_worker_service.dart';
import 'package:kbsync/features/resident/data/resident_location_service.dart';
import 'package:kbsync/core/widgets/kb_bottom_nav.dart';
import 'package:kbsync/core/widgets/kb_buttons.dart';
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
          if (tab == KbNavTab.tasks) {
            Navigator.of(context).pushNamed(AppRoutes.createTask);
          }
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
              child: const _TaskBottomSheet(),
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
                      flags: InteractiveFlag.all,
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
  const _TaskBottomSheet();
  static const _locationService = ResidentLocationService();
  static final _workerService = NearbyWorkerService();
  static const _distance = Distance();

  String _formatRating(double? rating) {
    final value = rating ?? 4.7;
    return value.toStringAsFixed(1);
  }

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
                                kNearbyRadiusMeters,
                          )
                          .toList(growable: false);

                  final nearbyWorkers =
                      workers
                          .map(
                            (worker) => (
                              worker: worker,
                              meters: _distance.as(
                                LengthUnit.Meter,
                                center,
                                worker.position,
                              ),
                            ),
                          )
                          .toList(growable: false)
                        ..sort((a, b) => a.meters.compareTo(b.meters));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Workers Near You (2km)',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: -0.4,
                              color: AppColors.ink,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${nearbyWorkers.length} available',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (nearbyWorkers.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.ink.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            'No workers currently within 2km. Please check again in a moment.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.ink.withValues(alpha: 0.65),
                            ),
                          ),
                        )
                      else
                        ...nearbyWorkers
                            .take(3)
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    8,
                                    10,
                                    8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.ink.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          gradient: AppColors.grad,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _initialForName(item.worker.name),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.worker.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: AppColors.ink,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.star_rounded,
                                                  size: 11,
                                                  color: Color(0xFFF59E0B),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatRating(
                                                    item.worker.rating,
                                                  ),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                    color: AppColors.ink,
                                                  ),
                                                ),
                                                Text(
                                                  _distanceLabel(item.meters),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.ink
                                                        .withValues(
                                                          alpha: 0.55,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const KbStatusTag.green('VERIFIED'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
