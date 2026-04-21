import 'dart:convert';
import 'dart:io';

class DiditIdVerificationResult {
  final String requestId;
  final String status;
  final String? fullName;
  final String? dateOfBirth;
  final String? sex;
  final String? idNumber;

  const DiditIdVerificationResult({
    required this.requestId,
    required this.status,
    this.fullName,
    this.dateOfBirth,
    this.sex,
    this.idNumber,
  });

  factory DiditIdVerificationResult.fromJson(Map<String, dynamic> json) {
    final verification = json['id_verification'];
    final verificationMap = verification is Map<String, dynamic>
        ? verification
        : verification is Map
            ? Map<String, dynamic>.from(verification)
            : <String, dynamic>{};

    final fullName = _firstNonEmpty([
      json['fullName'],
      verificationMap['full_name'],
      [verificationMap['first_name'], verificationMap['last_name']]
          .whereType<String>()
          .join(' ')
          .trim(),
      verificationMap['first_name'],
      verificationMap['last_name'],
    ]);

    return DiditIdVerificationResult(
      requestId:
          (json['requestId'] as String?) ?? (json['request_id'] as String?) ?? '',
      status:
          (json['status'] as String?) ?? (verificationMap['status'] as String?) ?? 'pending',
      fullName: fullName,
      dateOfBirth: _firstNonEmpty([
        json['dateOfBirth'],
        verificationMap['date_of_birth'],
        verificationMap['dob'],
      ]),
      sex: _firstNonEmpty([
        json['sex'],
        verificationMap['gender'],
        verificationMap['sex'],
      ]),
      idNumber: _firstNonEmpty([
        json['idNumber'],
        verificationMap['document_number'],
        verificationMap['personal_number'],
        verificationMap['id_number'],
      ]),
    );
  }
}

class DiditPassiveLivenessResult {
  final String requestId;
  final String status;
  final String method;
  final double? score;
  final double? faceQuality;
  final double? faceLuminance;

  const DiditPassiveLivenessResult({
    required this.requestId,
    required this.status,
    required this.method,
    this.score,
    this.faceQuality,
    this.faceLuminance,
  });

  bool get isApproved => status.trim().toLowerCase() == 'approved';

  factory DiditPassiveLivenessResult.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final liveness = json['liveness'];
    final livenessMap = liveness is Map<String, dynamic>
        ? liveness
        : liveness is Map
            ? Map<String, dynamic>.from(liveness)
            : <String, dynamic>{};

    return DiditPassiveLivenessResult(
      requestId:
          (json['requestId'] as String?) ?? (json['request_id'] as String?) ?? '',
      status: (json['status'] as String?) ??
          (livenessMap['status'] as String?) ??
          'pending',
      method: (json['method'] as String?) ??
          (livenessMap['method'] as String?) ??
          'PASSIVE',
      score: asDouble(json['score']) ?? asDouble(livenessMap['score']),
      faceQuality: asDouble(json['faceQuality']) ?? asDouble(livenessMap['face_quality']),
      faceLuminance:
          asDouble(json['faceLuminance']) ?? asDouble(livenessMap['face_luminance']),
    );
  }
}

class DiditFaceMatchResult {
  final String requestId;
  final String status;
  final double? score;

  const DiditFaceMatchResult({
    required this.requestId,
    required this.status,
    this.score,
  });

  bool get isApproved => status.trim().toLowerCase() == 'approved';

  factory DiditFaceMatchResult.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final faceMatch = json['face_match'];
    final faceMatchMap = faceMatch is Map<String, dynamic>
        ? faceMatch
        : faceMatch is Map
            ? Map<String, dynamic>.from(faceMatch)
            : <String, dynamic>{};

    return DiditFaceMatchResult(
      requestId:
          (json['requestId'] as String?) ?? (json['request_id'] as String?) ?? '',
      status:
          (json['status'] as String?) ?? (faceMatchMap['status'] as String?) ?? 'pending',
      score: asDouble(json['score']) ?? asDouble(faceMatchMap['score']),
    );
  }
}

String? _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

class VerificationApiService {
  VerificationApiService({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  static const String _baseUrl = String.fromEnvironment(
    'KBSYNC_ID_VERIFIER_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  final HttpClient _httpClient;

  Future<DiditIdVerificationResult> verifyDocument({
    required String userId,
    required String documentLabel,
    required String frontImagePath,
    String? backImagePath,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/didit/id-verification');
    final response = await _sendJson(
      method: 'POST',
      uri: uri,
      payload: {
        'userId': userId,
        'documentLabel': documentLabel,
        'frontImageBase64': base64Encode(await File(frontImagePath).readAsBytes()),
        if (backImagePath != null && backImagePath.trim().isNotEmpty)
          'backImageBase64': base64Encode(await File(backImagePath).readAsBytes()),
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _extractError(response.body) ?? 'Unable to verify identity document.',
      );
    }

    return DiditIdVerificationResult.fromJson(response.body);
  }

  Future<DiditPassiveLivenessResult> verifyPassiveLiveness({
    required String userId,
    required String userImagePath,
    int? faceLivenessScoreDeclineThreshold,
    bool rotateImage = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/didit/passive-liveness');
    final response = await _sendJson(
      method: 'POST',
      uri: uri,
      payload: {
        'userId': userId,
        'userImageBase64': base64Encode(await File(userImagePath).readAsBytes()),
        ...faceLivenessScoreDeclineThreshold == null
            ? {}
            : {
                'faceLivenessScoreDeclineThreshold':
                    faceLivenessScoreDeclineThreshold,
              },
        'rotateImage': rotateImage,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _extractError(response.body) ?? 'Unable to perform passive liveness check.',
      );
    }

    return DiditPassiveLivenessResult.fromJson(response.body);
  }

  Future<DiditFaceMatchResult> verifyFaceMatch({
    required String userId,
    required String userImagePath,
    required String refImagePath,
    int? faceMatchScoreDeclineThreshold,
    bool rotateImage = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/didit/face-match');
    final response = await _sendJson(
      method: 'POST',
      uri: uri,
      payload: {
        'userId': userId,
        'userImageBase64': base64Encode(await File(userImagePath).readAsBytes()),
        'refImageBase64': base64Encode(await File(refImagePath).readAsBytes()),
        ...faceMatchScoreDeclineThreshold == null
            ? {}
            : {
                'faceMatchScoreDeclineThreshold':
                    faceMatchScoreDeclineThreshold,
              },
        'rotateImage': rotateImage,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _extractError(response.body) ?? 'Unable to perform face match.',
      );
    }

    return DiditFaceMatchResult.fromJson(response.body);
  }

  Future<_ApiResponse> _sendJson({
    required String method,
    required Uri uri,
    Map<String, dynamic>? payload,
  }) async {
    final request = await _httpClient.openUrl(method, uri);
    request.headers.contentType = ContentType.json;
    if (payload != null) {
      request.write(jsonEncode(payload));
    }

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    return _ApiResponse(
      statusCode: response.statusCode,
      body: _decode(responseBody),
    );
  }

  static Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return {};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {};
  }

  static String? _extractError(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is String && error.isNotEmpty) return error;

    final message = body['message'];
    if (message is String && message.isNotEmpty) return message;

    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) return detail;

    return null;
  }
}

class _ApiResponse {
  final int statusCode;
  final Map<String, dynamic> body;

  const _ApiResponse({required this.statusCode, required this.body});
}
