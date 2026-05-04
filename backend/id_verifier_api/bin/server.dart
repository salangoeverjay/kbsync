import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dotenv/dotenv.dart' show DotEnv;
import 'package:id_verifier_api/src/didit_client.dart';
import 'package:id_verifier_api/src/firestore_client.dart';
import 'package:id_verifier_api/src/scan_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

Future<void> main() async {
  final env = DotEnv(includePlatformEnvironment: true)..load();

  final diditApiKey = env['DIDIT_API_KEY'];
  if (diditApiKey == null || diditApiKey.isEmpty) {
    stderr.writeln('Missing DIDIT_API_KEY environment variable.');
    exitCode = 64;
    return;
  }

  final diditClient = DiditClient(
    apiKey: diditApiKey,
  );

  // Optional: Firestore Admin client for the task entrance/exit scan flow.
  // Skipped (and the scan endpoints disabled) if no service account file is
  // configured — this keeps the existing /api/didit/* endpoints usable when
  // someone is hacking on auth without setting up Firestore credentials.
  final serviceAccountPath = env['FIRESTORE_SERVICE_ACCOUNT'];
  FirestoreClient? firestoreClient;
  TaskScanService? scanService;
  if (serviceAccountPath != null && serviceAccountPath.isNotEmpty) {
    try {
      firestoreClient =
          await FirestoreClient.fromServiceAccountFile(serviceAccountPath);
      scanService = TaskScanService(
        diditClient: diditClient,
        firestore: firestoreClient,
      );
      stdout.writeln('Firestore client ready (project=${firestoreClient.projectId}).');
    } catch (e) {
      stderr.writeln('Failed to init Firestore client: $e');
      stderr.writeln('Task scan endpoints will be disabled.');
    }
  } else {
    stderr.writeln(
      'FIRESTORE_SERVICE_ACCOUNT not set; /api/task/* endpoints disabled.',
    );
  }

  final router = Router()
    ..post('/api/didit/id-verification', (Request request) async {
      try {
        final body = await request.readAsString();
        final jsonBody = jsonDecode(body);
        if (jsonBody is! Map<String, dynamic>) {
          return _badRequest('Request body must be a JSON object.');
        }

        final userId = (jsonBody['userId'] as String?)?.trim();
        final frontImageBase64 = (jsonBody['frontImageBase64'] as String?)?.trim();
        final backImageBase64 = (jsonBody['backImageBase64'] as String?)?.trim();

        if (userId == null || userId.isEmpty) {
          return _badRequest('userId is required.');
        }

        if (frontImageBase64 == null || frontImageBase64.isEmpty) {
          return _badRequest('frontImageBase64 is required.');
        }

        final result = await diditClient.verifyIdentity(
          userId: userId,
          frontImageBytes: base64Decode(frontImageBase64),
          backImageBytes: (backImageBase64 == null || backImageBase64.isEmpty)
              ? null
              : base64Decode(backImageBase64),
        );

        return _jsonResponse(200, result);
      } on FormatException {
        return _badRequest('Invalid JSON body.');
      } on DiditClientException catch (e) {
        return _jsonResponse(e.statusCode, {
          'error': e.message,
        });
      } catch (_) {
        return _jsonResponse(500, {
          'error': 'Internal server error.',
        });
      }
    })
    ..post('/api/didit/passive-liveness', (Request request) async {
      try {
        final body = await request.readAsString();
        final jsonBody = jsonDecode(body);
        if (jsonBody is! Map<String, dynamic>) {
          return _badRequest('Request body must be a JSON object.');
        }

        final userId = (jsonBody['userId'] as String?)?.trim();
        final userImageBase64 = (jsonBody['userImageBase64'] as String?)?.trim();
        final threshold = jsonBody['faceLivenessScoreDeclineThreshold'];
        final rotateImage = jsonBody['rotateImage'] == true;

        if (userId == null || userId.isEmpty) {
          return _badRequest('userId is required.');
        }

        if (userImageBase64 == null || userImageBase64.isEmpty) {
          return _badRequest('userImageBase64 is required.');
        }

        final parsedThreshold = threshold is num ? threshold.toInt() : null;
        if (parsedThreshold != null &&
            (parsedThreshold < 0 || parsedThreshold > 100)) {
          return _badRequest(
            'faceLivenessScoreDeclineThreshold must be between 0 and 100.',
          );
        }

        final result = await diditClient.verifyPassiveLiveness(
          userId: userId,
          userImageBytes: base64Decode(userImageBase64),
          faceLivenessScoreDeclineThreshold: parsedThreshold,
          rotateImage: rotateImage,
        );

        return _jsonResponse(200, result);
      } on FormatException {
        return _badRequest('Invalid JSON body or base64 image.');
      } on DiditClientException catch (e) {
        return _jsonResponse(e.statusCode, {
          'error': e.message,
        });
      } catch (_) {
        return _jsonResponse(500, {
          'error': 'Internal server error.',
        });
      }
    })
    ..post('/api/didit/face-match', (Request request) async {
      try {
        final body = await request.readAsString();
        final jsonBody = jsonDecode(body);
        if (jsonBody is! Map<String, dynamic>) {
          return _badRequest('Request body must be a JSON object.');
        }

        final userId = (jsonBody['userId'] as String?)?.trim();
        final userImageBase64 = (jsonBody['userImageBase64'] as String?)?.trim();
        final refImageBase64 = (jsonBody['refImageBase64'] as String?)?.trim();
        final threshold = jsonBody['faceMatchScoreDeclineThreshold'];
        final rotateImage = jsonBody['rotateImage'] == true;

        if (userId == null || userId.isEmpty) {
          return _badRequest('userId is required.');
        }
        if (userImageBase64 == null || userImageBase64.isEmpty) {
          return _badRequest('userImageBase64 is required.');
        }
        if (refImageBase64 == null || refImageBase64.isEmpty) {
          return _badRequest('refImageBase64 is required.');
        }

        final parsedThreshold = threshold is num ? threshold.toInt() : null;
        if (parsedThreshold != null &&
            (parsedThreshold < 0 || parsedThreshold > 100)) {
          return _badRequest(
            'faceMatchScoreDeclineThreshold must be between 0 and 100.',
          );
        }

        final result = await diditClient.verifyFaceMatch(
          userId: userId,
          userImageBytes: base64Decode(userImageBase64),
          refImageBytes: base64Decode(refImageBase64),
          faceMatchScoreDeclineThreshold: parsedThreshold,
          rotateImage: rotateImage,
        );

        return _jsonResponse(200, result);
      } on FormatException {
        return _badRequest('Invalid JSON body or base64 image.');
      } on DiditClientException catch (e) {
        return _jsonResponse(e.statusCode, {
          'error': e.message,
        });
      } catch (_) {
        return _jsonResponse(500, {
          'error': 'Internal server error.',
        });
      }
    })
    ..post('/api/task/entrance-scan', (Request request) {
      return _handleScanRequest(
        request: request,
        scanService: scanService,
        runner: (svc, req) => svc.runEntranceScan(req),
      );
    })
    ..post('/api/task/exit-scan', (Request request) {
      return _handleScanRequest(
        request: request,
        scanService: scanService,
        runner: (svc, req) => svc.runExitScan(req),
      );
    })
    ..get('/health', (Request request) => _jsonResponse(200, {'ok': true}));

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router.call);

  final port = int.tryParse(env['PORT'] ?? '') ?? 8080;
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('id_verifier_api listening on http://${server.address.host}:${server.port}');
}

Response _badRequest(String message) {
  return _jsonResponse(400, {'error': message});
}

Response _jsonResponse(int statusCode, Map<String, dynamic> body) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {
      HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
    },
  );
}

typedef _ScanRunner = Future<TaskScanOutcome> Function(
  TaskScanService service,
  TaskScanRequest req,
);

/// Shared parser + runner for /api/task/entrance-scan and /api/task/exit-scan.
/// Returns a 503 if the Firestore service-account is not configured.
Future<Response> _handleScanRequest({
  required Request request,
  required TaskScanService? scanService,
  required _ScanRunner runner,
}) async {
  if (scanService == null) {
    return _jsonResponse(503, {
      'error':
          'Task scan endpoints are disabled — FIRESTORE_SERVICE_ACCOUNT not configured.',
    });
  }

  try {
    final body = await request.readAsString();
    final jsonBody = jsonDecode(body);
    if (jsonBody is! Map<String, dynamic>) {
      return _badRequest('Request body must be a JSON object.');
    }

    final taskId = (jsonBody['taskId'] as String?)?.trim();
    final workerUid = (jsonBody['workerUid'] as String?)?.trim();
    final workerName = (jsonBody['workerName'] as String?)?.trim();
    final selfieBase64 =
        (jsonBody['selfieImageBase64'] as String?)?.trim();
    final lat = jsonBody['lat'];
    final lng = jsonBody['lng'];

    if (taskId == null || taskId.isEmpty) {
      return _badRequest('taskId is required.');
    }
    if (workerUid == null || workerUid.isEmpty) {
      return _badRequest('workerUid is required.');
    }
    if (selfieBase64 == null || selfieBase64.isEmpty) {
      return _badRequest('selfieImageBase64 is required.');
    }
    if (lat is! num || lng is! num) {
      return _badRequest('lat and lng must be numbers.');
    }

    final Uint8List selfieBytes;
    try {
      selfieBytes = base64Decode(selfieBase64);
    } on FormatException {
      return _badRequest('selfieImageBase64 is not valid base64.');
    }

    final outcome = await runner(
      scanService,
      TaskScanRequest(
        taskId: taskId,
        workerUid: workerUid,
        selfieBytes: selfieBytes,
        lat: lat.toDouble(),
        lng: lng.toDouble(),
        workerName:
            (workerName != null && workerName.isNotEmpty) ? workerName : null,
      ),
    );

    final statusCode = switch (outcome.kind) {
      TaskScanOutcomeKind.passed => 200,
      TaskScanOutcomeKind.failed => 200, // logical fail, not HTTP fail
      TaskScanOutcomeKind.locked => 423, // Locked
      TaskScanOutcomeKind.outOfRange => 200, // logical fail
      TaskScanOutcomeKind.error => 500,
    };

    return _jsonResponse(statusCode, outcome.toJson());
  } on FormatException {
    return _badRequest('Invalid JSON body.');
  } catch (e) {
    stderr.writeln('Scan request failed: $e');
    return _jsonResponse(500, {
      'error': 'Internal server error.',
    });
  }
}
