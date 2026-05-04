import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CashInSourceResult {
  final String sourceId;
  final String? checkoutUrl;
  final String status;

  const CashInSourceResult({
    required this.sourceId,
    required this.checkoutUrl,
    required this.status,
  });
}

class TaskQrPaymentResult {
  final String paymentIntentId;
  final String? qrCodeUrl;
  final String? qrCodeData;
  final String status;

  const TaskQrPaymentResult({
    required this.paymentIntentId,
    required this.qrCodeUrl,
    required this.qrCodeData,
    required this.status,
  });
}

class PaymongoService {
  PaymongoService({FirebaseFunctions? functions})
    : _functions = functions ?? _buildFunctions();

  static const _region = 'asia-southeast1';
  static const _projectId = 'kabayansync';

  // Set with --dart-define=KBSYNC_USE_FUNCTIONS_EMULATOR=true when running
  // against `firebase emulators:start --only functions`.
  static const _useEmulator = bool.fromEnvironment(
    'KBSYNC_USE_FUNCTIONS_EMULATOR',
  );

  // Default: 10.0.2.2 (Android emulator → host loopback). Override with
  // --dart-define=KBSYNC_FUNCTIONS_EMULATOR_HOST=<ip-or-host> for iOS sim
  // (use 'localhost') or a real device on Wi-Fi (use the laptop's LAN IP).
  static const _emulatorHost = String.fromEnvironment(
    'KBSYNC_FUNCTIONS_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );
  static const _emulatorPort = int.fromEnvironment(
    'KBSYNC_FUNCTIONS_EMULATOR_PORT',
    defaultValue: 5001,
  );

  static FirebaseFunctions _buildFunctions() {
    final functions = FirebaseFunctions.instanceFor(region: _region);
    return functions;
  }

  final FirebaseFunctions _functions;

  Future<CashInSourceResult> createCashInSource({
    required double amountPesos,
    required String sourceType,
    String? successUrl,
    String? failedUrl,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (_useEmulator && (userId == null || userId.isEmpty)) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Sign in required to test cash in in emulator mode.',
      );
    }

    final result = await _invokeFunction('createCashInSource', <
      String,
      dynamic
    >{
      'amountPesos': amountPesos,
      'sourceType': sourceType,
      if (_useEmulator && userId != null && userId.isNotEmpty) 'userId': userId,
      if (successUrl != null && successUrl.isNotEmpty) 'successUrl': successUrl,
      if (failedUrl != null && failedUrl.isNotEmpty) 'failedUrl': failedUrl,
    });
    final data = result;
    return CashInSourceResult(
      sourceId: data['sourceId'] as String,
      checkoutUrl: data['checkoutUrl'] as String?,
      status: data['status'] as String? ?? 'pending',
    );
  }

  Future<TaskQrPaymentResult> createTaskQrPayment({
    required double amountPesos,
    required String taskId,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (_useEmulator && (userId == null || userId.isEmpty)) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Sign in required to test QR payment in emulator mode.',
      );
    }

    final result =
        await _invokeFunction('createTaskQrPayment', <String, dynamic>{
          'amountPesos': amountPesos,
          'taskId': taskId,
          if (_useEmulator && userId != null && userId.isNotEmpty)
            'userId': userId,
        });
    final data = result;
    return TaskQrPaymentResult(
      paymentIntentId: data['paymentIntentId'] as String,
      qrCodeUrl: data['qrCodeUrl'] as String?,
      qrCodeData: data['qrCodeData'] as String?,
      status: data['status'] as String? ?? 'awaiting_payment_method',
    );
  }

  Future<Map<String, dynamic>> _invokeFunction(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    if (_useEmulator) {
      return _invokeEmulatorFunction(functionName, data);
    }

    final callable = _functions.httpsCallable(functionName);
    final result = await callable.call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> requestWithdraw({
    required double amountPesos,
    String? destination,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (_useEmulator && (userId == null || userId.isEmpty)) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Sign in required to test withdraw in emulator mode.',
      );
    }

    final result = await _invokeFunction('requestWithdraw', <String, dynamic>{
      'amountPesos': amountPesos,
      ...?(_useEmulator && userId != null && userId.isNotEmpty
          ? <String, dynamic>{'userId': userId}
          : null),
      ...?(destination != null
          ? <String, dynamic>{'destination': destination}
          : null),
    });
    return result;
  }

  Future<Map<String, dynamic>> createPayout(
    Map<String, dynamic> payoutData,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (_useEmulator && (userId == null || userId.isEmpty)) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Sign in required to test payout in emulator mode.',
      );
    }

    final result = await _invokeFunction('createPayout', <String, dynamic>{
      ...payoutData,
      ...?(_useEmulator && userId != null && userId.isNotEmpty
          ? <String, dynamic>{'userId': userId}
          : null),
    });
    return result;
  }

  Future<Map<String, dynamic>> _invokeEmulatorFunction(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse(
      'http://$_emulatorHost:$_emulatorPort/$_projectId/$_region/$functionName',
    );
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;

      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      request.write(jsonEncode(<String, dynamic>{'data': data}));

      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();
      final jsonBody = _decode(responseBody);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FirebaseFunctionsException(
          code: 'unavailable',
          message:
              _extractNestedError(jsonBody) ??
              _extractError(jsonBody) ??
              'Failed to call Functions emulator.',
        );
      }

      final result = jsonBody['result'];
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      return jsonBody;
    } finally {
      client.close(force: true);
    }
  }

  static Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  static String? _extractError(Map<String, dynamic> body) {
    final direct = body['error'];
    if (direct is String && direct.isNotEmpty) return direct;

    if (direct is Map) {
      final nested = Map<String, dynamic>.from(direct);
      final nestedMessage = nested['message'];
      if (nestedMessage is String && nestedMessage.isNotEmpty) {
        return nestedMessage;
      }
    }

    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) return detail;

    final message = body['message'];
    if (message is String && message.isNotEmpty) return message;

    return null;
  }

  static String? _extractNestedError(Map<String, dynamic> body) {
    final direct = body['error'];
    if (direct is Map) {
      final nested = Map<String, dynamic>.from(direct);
      final message = nested['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    return null;
  }
}
