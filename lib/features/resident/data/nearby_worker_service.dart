import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class NearbyWorkerMarker {
  final String uid;
  final String name;
  final LatLng position;
  final double? rating;

  const NearbyWorkerMarker({
    required this.uid,
    required this.name,
    required this.position,
    required this.rating,
  });
}

class NearbyWorkerService {
  final FirebaseFirestore _firestore;

  NearbyWorkerService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<NearbyWorkerMarker>> watchAvailableWorkers() {
    return _firestore
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final workers = <NearbyWorkerMarker>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final role = (data['role'] as String?)?.trim().toLowerCase();
            if (role != 'worker') {
              continue;
            }

            final position = _extractPosition(data);
            if (position == null) {
              continue;
            }

            final fullName = (data['fullName'] as String?)?.trim();
            final rating = _extractRating(data);
            workers.add(
              NearbyWorkerMarker(
                uid: doc.id,
                name: (fullName == null || fullName.isEmpty)
                    ? 'Worker'
                    : fullName,
                position: position,
                rating: rating,
              ),
            );
          }

          return workers;
        });
  }

  LatLng? _extractPosition(Map<String, dynamic> data) {
    final location = data['location'];
    if (location is GeoPoint) {
      return LatLng(location.latitude, location.longitude);
    }

    final latitude = data['latitude'];
    final longitude = data['longitude'];

    if (latitude is num && longitude is num) {
      return LatLng(latitude.toDouble(), longitude.toDouble());
    }

    return null;
  }

  double? _extractRating(Map<String, dynamic> data) {
    final rating =
        data['rating'] ?? data['averageRating'] ?? data['workerRating'];
    if (rating is num) return rating.toDouble();
    if (rating is String) return double.tryParse(rating);
    return null;
  }
}
