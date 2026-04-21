import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class DiditClientException implements Exception {
  final int statusCode;
  final String message;

  DiditClientException(this.statusCode, this.message);
}

class DiditClient {
  DiditClient({
    required this.apiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _httpClient;

  static final Uri _createSessionUri = Uri.parse(
    'https://verification.didit.me/v3/session/',
  );

  Uri _decisionUri(String sessionId) => Uri.parse(
    'https://verification.didit.me/v3/session/$sessionId/decision/',
  );

  static final Uri _idVerificationUri = Uri.parse(
    'https://verification.didit.me/v3/id-verification/',
  );

  static final Uri _passiveLivenessUri = Uri.parse(
    'https://verification.didit.me/v3/passive-liveness/',
  );

  static final Uri _faceMatchUri = Uri.parse(
    'https://verification.didit.me/v3/face-match/',
  );

  Future<Map<String, dynamic>> createSession({
    required String userId,
    String? documentLabel,
    String? workflowId,
  }) async {
    final payload = <String, dynamic>{
      'vendor_data': userId,
      'metadata': jsonEncode({
        'document_label': documentLabel,
        'source': 'kbsync-mobile',
      }),
    };

    if (workflowId != null && workflowId.isNotEmpty) {
      payload['workflow_id'] = workflowId;
    }

    final response = await _httpClient.post(
      _createSessionUri,
      headers: _headers,
      body: jsonEncode(payload),
    );

    final jsonBody = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DiditClientException(
        response.statusCode,
        _extractError(jsonBody) ?? 'Failed to create Didit session.',
      );
    }

    return {
      'sessionId': jsonBody['session_id'],
      'sessionToken': jsonBody['session_token'],
      'status': _normalizeStatus(jsonBody['status'] as String?),
      'url': jsonBody['url'],
      'workflowId': jsonBody['workflow_id'],
    };
  }

  Future<Map<String, dynamic>> retrieveDecision(String sessionId) async {
    final response = await _httpClient.get(
      _decisionUri(sessionId),
      headers: {
        'x-api-key': apiKey,
      },
    );

    final jsonBody = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DiditClientException(
        response.statusCode,
        _extractError(jsonBody) ?? 'Failed to retrieve Didit session decision.',
      );
    }

    final idVerifications = jsonBody['id_verifications'];
    Map<String, dynamic>? firstIdVerification;
    if (idVerifications is List && idVerifications.isNotEmpty && idVerifications.first is Map) {
      firstIdVerification = Map<String, dynamic>.from(idVerifications.first as Map);
    }

    String? firstNonEmptyString(List<dynamic> values) {
      for (final value in values) {
        final text = value?.toString().trim();
        if (text != null && text.isNotEmpty) {
          return text;
        }
      }
      return null;
    }

    String? dateValue(Map<String, dynamic>? source) {
      if (source == null) return null;
      return firstNonEmptyString([
        source['date_of_birth'],
        source['dob'],
        source['birth_date'],
        source['birthday'],
      ]);
    }

    String? nameValue(Map<String, dynamic>? source) {
      if (source == null) return null;
      return firstNonEmptyString([
        source['full_name'],
        source['name'],
        source['document_holder_name'],
        source['holder_name'],
      ]);
    }

    String? sexValue(Map<String, dynamic>? source) {
      if (source == null) return null;
      return firstNonEmptyString([
        source['gender'],
        source['sex'],
      ]);
    }

    String? idNumberValue(Map<String, dynamic>? source) {
      if (source == null) return null;
      return firstNonEmptyString([
        source['document_number'],
        source['personal_number'],
        source['id_number'],
        source['number'],
      ]);
    }

    return {
      'sessionId': jsonBody['session_id'],
      'status': _normalizeStatus(jsonBody['status'] as String?),
      'fullName': firstNonEmptyString([
        nameValue(firstIdVerification),
        nameValue(jsonBody),
      ]),
      'dateOfBirth': firstNonEmptyString([
        dateValue(firstIdVerification),
        dateValue(jsonBody),
      ]),
      'sex': firstNonEmptyString([
        sexValue(firstIdVerification),
        sexValue(jsonBody),
      ]),
      'idNumber': firstNonEmptyString([
        idNumberValue(firstIdVerification),
        idNumberValue(jsonBody),
      ]),
      'raw': {
        'workflowId': jsonBody['workflow_id'],
        'features': jsonBody['features'],
      },
    };
  }

  Future<Map<String, dynamic>> verifyIdentity({
    required String userId,
    required Uint8List frontImageBytes,
    Uint8List? backImageBytes,
  }) async {
    final request = http.MultipartRequest('POST', _idVerificationUri)
      ..headers['x-api-key'] = apiKey
      ..fields['vendor_data'] = userId
      ..fields['save_api_request'] = 'true'
      ..fields['perform_document_liveness'] = 'false'
      ..fields['preferred_characters'] = 'latin'
      ..files.add(http.MultipartFile.fromBytes(
        'front_image',
        frontImageBytes,
        filename: 'front_image.jpg',
      ));

    if (backImageBytes != null && backImageBytes.isNotEmpty) {
      request.files.add(http.MultipartFile.fromBytes(
        'back_image',
        backImageBytes,
        filename: 'back_image.jpg',
      ));
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final jsonBody = _decode(responseBody);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DiditClientException(
        response.statusCode,
        _extractError(jsonBody) ?? 'Failed to verify identity document.',
      );
    }

    final verification = jsonBody['id_verification'];
    final verificationMap = verification is Map<String, dynamic>
        ? verification
        : verification is Map
            ? Map<String, dynamic>.from(verification)
            : <String, dynamic>{};

    return {
      'requestId': jsonBody['request_id'],
      'status': verificationMap['status'] ?? 'pending',
      'fullName': _firstNonEmpty([
        verificationMap['full_name'],
        verificationMap['name'],
        [verificationMap['first_name'], verificationMap['last_name']]
            .whereType<String>()
            .join(' ')
            .trim(),
      ]),
      'dateOfBirth': _firstNonEmpty([
        verificationMap['date_of_birth'],
        verificationMap['dob'],
      ]),
      'sex': _firstNonEmpty([
        verificationMap['gender'],
        verificationMap['sex'],
      ]),
      'idNumber': _firstNonEmpty([
        verificationMap['document_number'],
        verificationMap['personal_number'],
        verificationMap['id_number'],
      ]),
      'raw': jsonBody,
    };
  }

  Future<Map<String, dynamic>> verifyPassiveLiveness({
    required String userId,
    required Uint8List userImageBytes,
    int? faceLivenessScoreDeclineThreshold,
    bool rotateImage = false,
  }) async {
    final request = http.MultipartRequest('POST', _passiveLivenessUri)
      ..headers['x-api-key'] = apiKey
      ..fields['vendor_data'] = userId
      ..fields['save_api_request'] = 'true'
      ..fields['rotate_image'] = rotateImage.toString()
      ..files.add(http.MultipartFile.fromBytes(
        'user_image',
        userImageBytes,
        filename: 'selfie.jpg',
      ));

    if (faceLivenessScoreDeclineThreshold != null) {
      request.fields['face_liveness_score_decline_threshold'] =
          faceLivenessScoreDeclineThreshold.toString();
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final jsonBody = _decode(responseBody);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DiditClientException(
        response.statusCode,
        _extractError(jsonBody) ?? 'Failed to verify passive liveness.',
      );
    }

    final liveness = jsonBody['liveness'];
    final livenessMap = liveness is Map<String, dynamic>
        ? liveness
        : liveness is Map
            ? Map<String, dynamic>.from(liveness)
            : <String, dynamic>{};

    final score = livenessMap['score'];

    return {
      'requestId': jsonBody['request_id'],
      'status': _firstNonEmpty([livenessMap['status'], 'pending']),
      'method': _firstNonEmpty([livenessMap['method'], 'PASSIVE']),
      'score': score is num ? score.toDouble() : null,
      'faceQuality': (livenessMap['face_quality'] is num)
          ? (livenessMap['face_quality'] as num).toDouble()
          : null,
      'faceLuminance': (livenessMap['face_luminance'] is num)
          ? (livenessMap['face_luminance'] as num).toDouble()
          : null,
      'raw': jsonBody,
    };
  }

  Future<Map<String, dynamic>> verifyFaceMatch({
    required String userId,
    required Uint8List userImageBytes,
    required Uint8List refImageBytes,
    int? faceMatchScoreDeclineThreshold,
    bool rotateImage = false,
  }) async {
    final request = http.MultipartRequest('POST', _faceMatchUri)
      ..headers['x-api-key'] = apiKey
      ..fields['vendor_data'] = userId
      ..fields['save_api_request'] = 'true'
      ..fields['rotate_image'] = rotateImage.toString()
      ..files.add(http.MultipartFile.fromBytes(
        'user_image',
        userImageBytes,
        filename: 'user_image.jpg',
      ))
      ..files.add(http.MultipartFile.fromBytes(
        'ref_image',
        refImageBytes,
        filename: 'ref_image.jpg',
      ));

    if (faceMatchScoreDeclineThreshold != null) {
      request.fields['face_match_score_decline_threshold'] =
          faceMatchScoreDeclineThreshold.toString();
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final jsonBody = _decode(responseBody);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DiditClientException(
        response.statusCode,
        _extractError(jsonBody) ?? 'Failed to verify face match.',
      );
    }

    final faceMatch = jsonBody['face_match'];
    final faceMatchMap = faceMatch is Map<String, dynamic>
        ? faceMatch
        : faceMatch is Map
            ? Map<String, dynamic>.from(faceMatch)
            : <String, dynamic>{};

    final score = faceMatchMap['score'];

    return {
      'requestId': jsonBody['request_id'],
      'status': _firstNonEmpty([faceMatchMap['status'], 'pending']),
      'score': score is num ? score.toDouble() : null,
      'raw': jsonBody,
    };
  }

  Map<String, String> get _headers => {
        'x-api-key': apiKey,
        'Content-Type': 'application/json',
      };

  static Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  static String _normalizeStatus(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'approved':
        return 'approved';
      case 'declined':
        return 'declined';
      case 'in review':
      case 'pending':
      case 'not started':
      default:
        return 'pending';
    }
  }

  static String? _extractError(Map<String, dynamic> body) {
    final direct = body['error'];
    if (direct is String && direct.isNotEmpty) return direct;

    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) return detail;

    final message = body['message'];
    if (message is String && message.isNotEmpty) return message;

    return null;
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}
