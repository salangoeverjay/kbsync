import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Result of a `/api/task/*` scan call. Mirrors `TaskScanOutcome` on the
/// backend ([backend/id_verifier_api/lib/src/scan_service.dart]).
class WorkerTaskScanResult {
  final WorkerTaskScanKind kind;
  final String? reason;
  final int? retriesRemaining;
  final DateTime? lockedUntil;
  final double? distanceMeters;
  final double? allowedMeters;
  final double? livenessScore;
  final double? faceMatchScore;
  final String? errorCode;
  final String? errorMessage;

  const WorkerTaskScanResult({
    required this.kind,
    this.reason,
    this.retriesRemaining,
    this.lockedUntil,
    this.distanceMeters,
    this.allowedMeters,
    this.livenessScore,
    this.faceMatchScore,
    this.errorCode,
    this.errorMessage,
  });

  factory WorkerTaskScanResult.fromJson(Map<String, dynamic> json) {
    final kind = _parseKind(json['kind']);
    DateTime? parseDate(dynamic raw) {
      if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
      return null;
    }

    double? asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return WorkerTaskScanResult(
      kind: kind,
      reason: json['reason'] as String?,
      retriesRemaining: json['retriesRemaining'] is int
          ? json['retriesRemaining'] as int
          : null,
      lockedUntil: parseDate(json['lockedUntil']),
      distanceMeters: asDouble(json['distanceMeters']),
      allowedMeters: asDouble(json['allowedMeters']),
      livenessScore: asDouble(json['livenessScore']),
      faceMatchScore: asDouble(json['faceMatchScore']),
      errorCode: json['errorCode'] as String?,
      errorMessage: json['errorMessage'] as String? ?? json['error'] as String?,
    );
  }

  static WorkerTaskScanKind _parseKind(dynamic raw) {
    switch (raw) {
      case 'passed':
        return WorkerTaskScanKind.passed;
      case 'failed':
        return WorkerTaskScanKind.failed;
      case 'locked':
        return WorkerTaskScanKind.locked;
      case 'outOfRange':
        return WorkerTaskScanKind.outOfRange;
      default:
        return WorkerTaskScanKind.error;
    }
  }
}

enum WorkerTaskScanKind { passed, failed, locked, outOfRange, error }

class WorkerTaskScanService {
  WorkerTaskScanService({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  static const String _baseUrl = String.fromEnvironment(
    'KBSYNC_ID_VERIFIER_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  final HttpClient _httpClient;

  Future<WorkerTaskScanResult> entranceScan({
    required String taskId,
    required String workerUid,
    required Uint8List selfieBytes,
    required double lat,
    required double lng,
    String? workerName,
  }) {
    return _post(
      path: '/api/task/entrance-scan',
      taskId: taskId,
      workerUid: workerUid,
      selfieBytes: selfieBytes,
      lat: lat,
      lng: lng,
      workerName: workerName,
    );
  }

  Future<WorkerTaskScanResult> exitScan({
    required String taskId,
    required String workerUid,
    required Uint8List selfieBytes,
    required double lat,
    required double lng,
  }) {
    return _post(
      path: '/api/task/exit-scan',
      taskId: taskId,
      workerUid: workerUid,
      selfieBytes: selfieBytes,
      lat: lat,
      lng: lng,
    );
  }

  Future<WorkerTaskScanResult> _post({
    required String path,
    required String taskId,
    required String workerUid,
    required Uint8List selfieBytes,
    required double lat,
    required double lng,
    String? workerName,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = await _httpClient.openUrl('POST', uri);
    request.headers.contentType = ContentType.json;

    final payload = <String, dynamic>{
      'taskId': taskId,
      'workerUid': workerUid,
      'selfieImageBase64': base64Encode(selfieBytes),
      'lat': lat,
      'lng': lng,
      if (workerName != null && workerName.isNotEmpty) 'workerName': workerName,
    };
    request.write(jsonEncode(payload));

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(body);
      json = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'kind': 'error', 'errorMessage': 'Bad response'};
    } on FormatException {
      json = <String, dynamic>{
        'kind': 'error',
        'errorMessage': 'Server returned non-JSON response.',
      };
    }

    // Backend returns 200 for passed/failed/outOfRange, 423 for locked,
    // 4xx/5xx for transport errors. Treat 423 as a structured `locked`
    // outcome rather than throwing.
    if (response.statusCode >= 400 && response.statusCode != 423) {
      return WorkerTaskScanResult(
        kind: WorkerTaskScanKind.error,
        errorCode: 'http_${response.statusCode}',
        errorMessage: json['errorMessage'] as String? ??
            json['error'] as String? ??
            'Server returned HTTP ${response.statusCode}.',
      );
    }

    return WorkerTaskScanResult.fromJson(json);
  }
}
