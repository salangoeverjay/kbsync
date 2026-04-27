import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:googleapis_auth/auth_io.dart' as auth;

/// Thin wrapper over the Firestore REST API used by backend scan endpoints.
///
/// We deliberately do not use the `firedart` community package — it is built
/// for end-user Auth tokens and does not handle service-account credentials
/// well. The official `googleapis` REST client is verbose but battle-tested.
class FirestoreClient {
  FirestoreClient._({
    required this.projectId,
    required fs.FirestoreApi api,
    required auth.AutoRefreshingAuthClient authClient,
  })  : _api = api,
        _authClient = authClient;

  final String projectId;
  final fs.FirestoreApi _api;
  final auth.AutoRefreshingAuthClient _authClient;

  static const _scopes = [
    'https://www.googleapis.com/auth/datastore',
    'https://www.googleapis.com/auth/cloud-platform',
  ];

  String get _basePath => 'projects/$projectId/databases/(default)/documents';

  /// Builds a client from a service-account JSON key on disk.
  static Future<FirestoreClient> fromServiceAccountFile(String path) async {
    final raw = await File(path).readAsString();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final credentials = auth.ServiceAccountCredentials.fromJson(json);
    final projectId = json['project_id'] as String?;
    if (projectId == null || projectId.isEmpty) {
      throw StateError(
        'Service account JSON at $path does not contain "project_id".',
      );
    }
    final client = await auth.clientViaServiceAccount(credentials, _scopes);
    return FirestoreClient._(
      projectId: projectId,
      api: fs.FirestoreApi(client),
      authClient: client,
    );
  }

  void close() => _authClient.close();

  /// Reads a document. Returns `null` if it does not exist.
  /// `path` is the doc path *relative to* the database root, e.g.
  /// `users/abc123/private/reference_face`.
  Future<Map<String, dynamic>?> getDoc(String path) async {
    final name = '$_basePath/$path';
    try {
      final doc = await _api.projects.databases.documents.get(name);
      return _decodeFields(doc.fields);
    } on fs.DetailedApiRequestError catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Patches a document with a sparse update. Creates the doc if missing.
  /// Pass dotted field paths for nested updates, e.g.
  /// `'scans.entrance.passed'`. The implementation translates the field
  /// list into Firestore's `updateMask.fieldPaths`.
  Future<void> patchDoc(
    String path,
    Map<String, dynamic> fields, {
    bool createIfMissing = true,
  }) async {
    final name = '$_basePath/$path';
    final encoded = _encodeFields(fields);
    final updateMaskPaths = fields.keys.toList(growable: false);

    await _api.projects.databases.documents.patch(
      fs.Document(fields: encoded),
      name,
      updateMask_fieldPaths: updateMaskPaths,
      currentDocument_exists: createIfMissing ? null : true,
    );
  }

  // ---------------------------------------------------------------------------
  // Value encoding helpers — Firestore REST wraps every primitive in a typed
  // object (e.g. {stringValue: "x"}, {integerValue: "5"}). We hide that
  // verbosity behind these helpers and a small set of sentinel types.
  // ---------------------------------------------------------------------------

  static Map<String, dynamic>? _decodeFields(Map<String, fs.Value>? fields) {
    if (fields == null) return null;
    return fields.map((k, v) => MapEntry(k, _decodeValue(v)));
  }

  static dynamic _decodeValue(fs.Value v) {
    if (v.stringValue != null) return v.stringValue;
    if (v.booleanValue != null) return v.booleanValue;
    if (v.integerValue != null) return int.parse(v.integerValue!);
    if (v.doubleValue != null) return v.doubleValue;
    if (v.timestampValue != null) return DateTime.parse(v.timestampValue!);
    if (v.nullValue != null) return null;
    if (v.mapValue != null) {
      return v.mapValue!.fields?.map(
            (k, val) => MapEntry(k, _decodeValue(val)),
          ) ??
          <String, dynamic>{};
    }
    if (v.arrayValue != null) {
      return v.arrayValue!.values?.map(_decodeValue).toList() ?? const [];
    }
    return null;
  }

  static Map<String, fs.Value> _encodeFields(Map<String, dynamic> fields) {
    return fields.map((k, v) => MapEntry(k, _encodeValue(v)));
  }

  static fs.Value _encodeValue(dynamic v) {
    if (v == null) return fs.Value(nullValue: 'NULL_VALUE');
    if (v is FirestoreServerTimestamp) {
      return fs.Value(timestampValue: DateTime.now().toUtc().toIso8601String());
    }
    if (v is bool) return fs.Value(booleanValue: v);
    if (v is int) return fs.Value(integerValue: v.toString());
    if (v is double) return fs.Value(doubleValue: v);
    if (v is String) return fs.Value(stringValue: v);
    if (v is DateTime) {
      return fs.Value(timestampValue: v.toUtc().toIso8601String());
    }
    if (v is Map<String, dynamic>) {
      return fs.Value(mapValue: fs.MapValue(fields: _encodeFields(v)));
    }
    if (v is List) {
      return fs.Value(
        arrayValue: fs.ArrayValue(values: v.map(_encodeValue).toList()),
      );
    }
    throw ArgumentError(
      'Cannot encode value of type ${v.runtimeType} for Firestore.',
    );
  }
}

/// Sentinel — encode as the current server time.
/// (Firestore REST does not have a real `serverTimestamp()` like the Admin
/// SDK. We approximate with the request-time clock; good enough for scan
/// audit timestamps.)
class FirestoreServerTimestamp {
  const FirestoreServerTimestamp();
}

const firestoreServerTimestamp = FirestoreServerTimestamp();
