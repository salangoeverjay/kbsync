# Task Scan Backend Setup

The `backend/id_verifier_api/` Dart server hosts the worker entrance/exit
biometric scan endpoints. This doc covers what you need to wire up before
the Flutter screens (Phase 4) can talk to it.

## Endpoints added in Phase 2

| Path | Method | Purpose |
|---|---|---|
| `POST /api/task/entrance-scan` | Worker proves identity at task start | |
| `POST /api/task/exit-scan` | Worker proves identity at task completion | |

### Request shape (both endpoints)

```json
{
  "taskId": "abc123",
  "workerUid": "firebase-uid",
  "selfieImageBase64": "<base64 jpg of fresh selfie>",
  "lat": 14.5995,
  "lng": 120.9842
}
```

### Response shape

`200` with one of:

```json
{ "kind": "passed", "livenessScore": 99.4, "faceMatchScore": 95.1 }
{ "kind": "failed", "reason": "liveness_failed", "retriesRemaining": 2 }
{ "kind": "failed", "reason": "face_match_failed", "retriesRemaining": 0,
  "lockedUntil": "2026-04-27T07:30:00.000Z" }
{ "kind": "outOfRange", "distanceMeters": 142.3, "allowedMeters": 50.0 }
```

`423` (Locked):
```json
{ "kind": "locked", "lockedUntil": "2026-04-27T07:30:00.000Z" }
```

`500` on backend errors, `400` on bad requests.

## What gets written to Firestore on each scan

| Path | Field | When |
|---|---|---|
| `tasks/{taskId}` | `scans.entrance` or `scans.exit` (map) | every scan |
| `tasks/{taskId}` | `statusLabel` -> `'In Progress'` | passed entrance |
| `tasks/{taskId}` | `statusLabel` -> `'Completed'` | passed exit |
| `users/{uid}` | `scanFailureCount` (int) | every scan |
| `users/{uid}` | `workerLockoutUntil` (timestamp) | on 3rd consecutive fail |

A successful scan resets `scanFailureCount` to 0.

## One-time setup

### 1. Generate a Firebase service-account key

Firebase Console -> https://console.firebase.google.com/project/kabayansync/settings/serviceaccounts/adminsdk

Click **Generate new private key**, save the downloaded file as:

```
backend/id_verifier_api/serviceAccountKey.json
```

This file is gitignored. **Do not commit it** — it has god-mode access to
your Firebase project.

### 2. Create `.env`

Copy `.env.example` to `.env` and fill in:

```env
DIDIT_API_KEY=your_didit_key
FIRESTORE_SERVICE_ACCOUNT=./serviceAccountKey.json
PORT=8080
```

### 3. Re-run the server

```bash
cd backend/id_verifier_api
dart run bin/server.dart
```

You should see:

```
Firestore client ready (project=kabayansync).
id_verifier_api listening on http://0.0.0.0:8080
```

If `FIRESTORE_SERVICE_ACCOUNT` is unset, the server still starts but the
scan endpoints return `503` — useful when you only need the existing
auth endpoints (`/api/didit/*`) and don't want to set up Firestore creds.

## How the scan flow works

1. **Lockout gate** — backend checks `users/{uid}.workerLockoutUntil`
   first. If still active, returns `423 locked` and skips Didit calls
   (saves quota).
2. **Reference photo lookup** — reads `users/{uid}/private/reference_face`
   (created in Phase 1 at sign-up). If missing, returns `error
   no_reference_photo`.
3. **Geofence** — Haversine distance between worker GPS and `tasks/{taskId}.lat/lng`.
   Default radius: 50 m (configurable in `TaskScanService`).
   Out of range -> retry-when-closer, no penalty.
4. **Didit liveness + face match** — only if geofence passes.
   The backend rejects only when Didit explicitly returns `declined`.
5. **Persistence** — scan record written to the task doc; success/fail
   counters updated on the user doc.

## Tuning knobs (in `lib/src/scan_service.dart`)

```dart
TaskScanService(
  diditClient: ...,
  firestore: ...,
  geofenceMeters: 50,            // 50 m radius
  maxFailures: 3,                // 3 fails -> lockout
  lockoutDuration: Duration(hours: 5),
  faceMatchScoreThreshold: 30,   // Didit decline threshold
  livenessScoreThreshold: 30,
);
```

## What's intentionally not yet wired

- **Phase 3:** failure-counter enforcement on `acceptTask` — the worker
  dashboard should refuse to even open a task when locked out.
- **Phase 4:** Flutter `EntranceScanScreen` / `ExitScanScreen` that call
  these endpoints with a fresh camera selfie + GPS.

These both come in subsequent phases. The backend is feature-complete for
the scan flow itself.

## Files added or modified in Phase 2

- `backend/id_verifier_api/lib/src/firestore_client.dart` (new)
- `backend/id_verifier_api/lib/src/scan_service.dart` (new)
- `backend/id_verifier_api/bin/server.dart` (added route handlers)
- `backend/id_verifier_api/pubspec.yaml` (`googleapis`, `googleapis_auth`)
- `backend/id_verifier_api/.gitignore` (new)
- `backend/id_verifier_api/.env.example` (new)
