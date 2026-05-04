import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Persists task evidence photos at `tasks/{taskId}/evidence/{n}`.
///
/// Same constraints as [ReferenceFaceService]: Spark plan blocks Storage,
/// so JPEG bytes are saved base64-encoded inside Firestore docs.
/// Each photo is compressed to fit comfortably under the 1 MiB doc cap.
class EvidenceService {
  EvidenceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Hard limit on the *raw* (pre-base64) bytes we will accept.
  /// 700 KB raw -> ~933 KB encoded, leaving headroom for metadata.
  static const int maxRawBytes = 700 * 1024;

  CollectionReference<Map<String, dynamic>> _evidenceCollection(String taskId) {
    return _firestore.collection('tasks').doc(taskId).collection('evidence');
  }

  /// Captures evidence #n for [taskId]. The doc id is the index in capture
  /// order (0-based, zero-padded so Firestore lists sort correctly).
  Future<String> uploadFromFile({
    required String taskId,
    required String workerUid,
    required String filePath,
    String? note,
  }) async {
    final compressed = await _compressForEvidence(filePath);
    return uploadFromBytes(
      taskId: taskId,
      workerUid: workerUid,
      bytes: compressed,
      note: note,
    );
  }

  Future<String> uploadFromBytes({
    required String taskId,
    required String workerUid,
    required Uint8List bytes,
    String? note,
  }) async {
    if (taskId.trim().isEmpty) {
      throw ArgumentError('taskId must not be empty.');
    }
    if (bytes.lengthInBytes > maxRawBytes) {
      throw ArgumentError(
        'Evidence photo too large: ${bytes.lengthInBytes} bytes '
        '(max $maxRawBytes).',
      );
    }

    final col = _evidenceCollection(taskId);
    final existing = await col.count().get();
    final index = existing.count ?? 0;
    final docId = index.toString().padLeft(3, '0');

    await col.doc(docId).set({
      'index': index,
      'workerUid': workerUid,
      'imageBase64': base64Encode(bytes),
      'contentType': 'image/jpeg',
      'sizeBytes': bytes.lengthInBytes,
      if (note != null && note.isNotEmpty) 'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Bump a counter on the task doc so resident dashboards can show
    // "3 photos uploaded" without listing the subcollection.
    await _firestore.collection('tasks').doc(taskId).set({
      'evidenceCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return docId;
  }

  /// Live count of evidence photos for a task. Used by the UI to enable
  /// the Submit button only after at least one capture.
  Stream<int> watchEvidenceCount(String taskId) {
    return _firestore
        .collection('tasks')
        .doc(taskId)
        .snapshots()
        .map((snap) => (snap.data()?['evidenceCount'] as int?) ?? 0);
  }

  static Future<Uint8List> _compressForEvidence(String filePath) async {
    const qualitySteps = [80, 70, 60, 50, 40];
    Uint8List? lastAttempt;
    for (final quality in qualitySteps) {
      final result = await FlutterImageCompress.compressWithFile(
        filePath,
        quality: quality,
        minWidth: 1080,
        minHeight: 1080,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (result == null) continue;
      lastAttempt = result;
      if (result.lengthInBytes <= maxRawBytes) return result;
    }
    if (lastAttempt != null) {
      throw StateError(
        'Evidence photo still too large after compression: '
        '${lastAttempt.lengthInBytes} bytes (max $maxRawBytes).',
      );
    }
    throw StateError('Failed to compress evidence photo at $filePath.');
  }
}
