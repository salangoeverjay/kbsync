import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class ResidentLocationService {
  const ResidentLocationService();

  static const LatLng fallbackLocation = LatLng(7.3077, 125.6833);

  Future<LatLng> getCurrentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return fallbackLocation;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return fallbackLocation;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return LatLng(position.latitude, position.longitude);
  }

  Stream<LatLng> locationStream() async* {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      yield fallbackLocation;
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      yield fallbackLocation;
      return;
    }

    final firstPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    yield LatLng(firstPosition.latitude, firstPosition.longitude);

    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).map((position) => LatLng(position.latitude, position.longitude));
  }

  List<LatLng> buildNearbyWorkerLocations(LatLng center) {
    return [
      _offset(center, 180, 120),
      _offset(center, -220, 160),
      _offset(center, 260, -140),
    ];
  }

  LatLng _offset(LatLng center, double eastMeters, double northMeters) {
    const earthRadius = 6378137.0;
    final dLat = northMeters / earthRadius;
    final dLng =
        eastMeters / (earthRadius * math.cos(center.latitude * math.pi / 180));

    return LatLng(
      center.latitude + dLat * 180 / math.pi,
      center.longitude + dLng * 180 / math.pi,
    );
  }
}
