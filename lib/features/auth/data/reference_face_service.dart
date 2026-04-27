import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Stores and retrieves the verified reference selfie used at sign-up
/// to back later face-match challenges (entrance/exit task scans).
///
/// Layout: `users/{uid}/private/reference_face`. The selfie sits in its own
/// subdoc (not the user doc) so the bytes are not pulled into the many
/// callers that read the user doc for auth/role/wallet.
///
/// On the Spark plan we cannot use Cloud Storage for binary blobs, so the
/// JPEG bytes are persisted base64-encoded inside the doc. Compressed
/// selfies are typically 30–80 KB (base64: 40–110 KB), well under the
/// 1 MB Firestore document cap.
class ReferenceFaceService {
  ReferenceFaceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Hard limit on the *raw* (pre-base64) bytes we will accept.
  /// Base64 is ~4/3 of the source, so 700 KB raw → ~933 KB encoded,
  /// leaving headroom under Firestore's 1 MiB doc limit for metadata.
  static const int maxRawBytes = 700 * 1024;

  DocumentReference<Map<String, dynamic>> _ref(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('reference_face');

  /// Uploads the verified selfie bytes for [uid].
  /// Overwrites any existing reference photo.
  Future<void> uploadFromBytes({
    required String uid,
    required Uint8List bytes,
  }) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('uid must not be empty.');
    }
    if (bytes.isEmpty) {
      throw ArgumentError('bytes must not be empty.');
    }
    if (bytes.lengthInBytes > maxRawBytes) {
      throw ArgumentError(
        'Reference selfie too large: ${bytes.lengthInBytes} bytes '
        '(max $maxRawBytes).',
      );
    }

    final encoded = base64Encode(bytes);
    final batch = _firestore.batch();

    batch.set(_ref(uid), {
      'uid': uid,
      'imageBase64': encoded,
      'contentType': 'image/jpeg',
      'sizeBytes': bytes.lengthInBytes,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Lightweight pointer on the user doc so callers (and security rules)
    // can cheaply check whether a reference photo exists, without pulling
    // the bytes themselves.
    batch.set(_firestore.collection('users').doc(uid), {
      'referenceFace': {
        'present': true,
        'sizeBytes': bytes.lengthInBytes,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Convenience wrapper for the common case where the selfie sits on disk
  /// (e.g. from `CameraController.takePicture()`). The image is recompressed
  /// to a JPEG that comfortably fits under [maxRawBytes].
  Future<void> uploadFromFile({
    required String uid,
    required String filePath,
  }) async {
    final compressed = await _compressForReference(filePath);
    await uploadFromBytes(uid: uid, bytes: compressed);
  }

  /// Re-encodes the source image at progressively lower quality until the
  /// result fits under [maxRawBytes]. Throws if even quality 40 won't fit.
  static Future<Uint8List> _compressForReference(String filePath) async {
    const qualitySteps = [80, 70, 60, 50, 40];
    Uint8List? lastAttempt;
    for (final quality in qualitySteps) {
      final result = await FlutterImageCompress.compressWithFile(
        filePath,
        quality: quality,
        minWidth: 720,
        minHeight: 720,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (result == null) continue;
      lastAttempt = result;
      if (result.lengthInBytes <= maxRawBytes) return result;
    }
    if (lastAttempt != null) {
      throw StateError(
        'Reference selfie still too large after compression: '
        '${lastAttempt.lengthInBytes} bytes (max $maxRawBytes).',
      );
    }
    throw StateError('Failed to compress reference selfie at $filePath.');
  }

  /// Returns the stored reference selfie bytes for [uid], or `null` if
  /// none exists. Backend code (entrance/exit scan) is the primary caller.
  Future<Uint8List?> downloadBytes(String uid) async {
    final snap = await _ref(uid).get();
    final data = snap.data();
    if (data == null) return null;
    final encoded = data['imageBase64'];
    if (encoded is! String || encoded.isEmpty) return null;
    return base64Decode(encoded);
  }

  /// Whether [uid] has a stored reference photo. Cheap check — reads the
  /// user doc pointer rather than the bytes subdoc.
  Future<bool> hasReference(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    final data = snap.data();
    if (data == null) return false;
    final ref = data['referenceFace'];
    return ref is Map && (ref['present'] as bool?) == true;
  }
}
