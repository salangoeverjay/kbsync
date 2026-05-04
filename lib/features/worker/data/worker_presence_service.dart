import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class WorkerPresenceService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StreamSubscription<Position>? _positionSubscription;

  WorkerPresenceService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  Future<void> setOnline(bool online) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return;
    }

    if (!online) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      await _firestore.collection('users').doc(uid).set({
        'isOnline': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final first = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    await _writePosition(uid, first, true);

    await _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) {
          _writePosition(uid, position, true);
        });
  }

  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> _writePosition(String uid, Position position, bool online) {
    return _firestore.collection('users').doc(uid).set({
      'isOnline': online,
      'location': GeoPoint(position.latitude, position.longitude),
      'locationUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
