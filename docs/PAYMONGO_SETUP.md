# PayMongo Integration Setup

This project uses **PayMongo** in **test mode only** (school project, no live transactions).

## Architecture

- **Flutter app** → calls Firebase Cloud Functions (asia-southeast1) via `cloud_functions` SDK.
- **Cloud Functions** (`functions/`) → hold the PayMongo secret key, proxy requests to PayMongo, and handle webhooks.
- **PayMongo** → returns a redirect checkout URL (cash in) or a QR code image (merchant QR).
- **Firestore** → wallet credit / task escrow status updated by the webhook handler.

```
Flutter ──callable──▶ Cloud Functions ──REST──▶ PayMongo
                              ▲                     │
                              └────── webhook ──────┘
                              (signed HMAC, updates Firestore)
```

## Two flows

### 1. Wallet cash in

`lib/features/wallet/presentation/screens/cash_in_screen.dart` → `createCashInSource` callable.

- GCash / Maya: PayMongo Sources API → opens redirect URL → webhook `source.chargeable` credits `users/{uid}.walletBalance`.
- Bank Transfer / OTC: fallback to local `WalletService.recordCashIn` (mock — not wired to a real rail in this build).

### 2. Grocery task with budget > ₱200

`lib/features/resident/presentation/screens/create_task_screen.dart` → `createTaskQrPayment` callable.

- Generates a **PayMongo QR Ph** PaymentIntent.
- Resident scans the QR with any QR Ph–compatible app.
- Webhook `payment.paid` flips `tasks/{taskId}.escrow.status` to `funded`.
- Funds sit in the platform PayMongo account until task completion (escrow logic for release is **not yet wired** — that belongs in the worker completion flow).

## One-time setup

### 1. Install Cloud Functions dependencies

```bash
cd functions
npm install
```

### 2. Set the secrets

PayMongo secret key:

```bash
firebase functions:secrets:set PAYMONGO_SECRET_KEY
# paste the test secret (starts with sk_test_)
```

Webhook signing secret (you'll get this after creating the webhook in step 4):

```bash
firebase functions:secrets:set PAYMONGO_WEBHOOK_SECRET
# paste the value PayMongo shows after creating the webhook
```

Verify:

```bash
firebase functions:secrets:access PAYMONGO_SECRET_KEY
```

### 3. Deploy the functions

From the repo root:

```bash
firebase deploy --only functions
```

After deploy, copy the URL of `paymongoWebhook` from the CLI output. It will look like:

```
https://asia-southeast1-kabayansync.cloudfunctions.net/paymongoWebhook
```

### 4. Register the webhook in PayMongo

PayMongo dashboard → Developers → Webhooks → **Create webhook**:

- **URL**: the `paymongoWebhook` URL from step 3.
- **Events**: `source.chargeable`, `payment.paid`, `payment.failed`.
- After saving, copy the **Signing secret** PayMongo shows and feed it back via `firebase functions:secrets:set PAYMONGO_WEBHOOK_SECRET`, then redeploy:

```bash
firebase deploy --only functions
```

### 5. Local development

The Flutter client points at `asia-southeast1` Cloud Functions by default. To run against the Functions emulator, swap to:

```dart
FirebaseFunctions.instanceFor(region: 'asia-southeast1')
  .useFunctionsEmulator('localhost', 5001);
```

The webhook needs a public URL even in dev — use `ngrok http 5001` and re-register the URL in PayMongo.

## Test cards / wallets

Use the credentials documented at https://developers.paymongo.com/docs/testing for test-mode GCash, Maya, and QR Ph payments.

## Security notes

- The PayMongo secret key **must never** be embedded in the Flutter app. It only exists inside Cloud Functions secrets.
- `verifyWebhookSignature` in `functions/src/paymongo.ts` enforces HMAC-SHA256 with timing-safe comparison.
- Each cash-in source / task intent is single-credit: `creditedAt` / `escrow.status` checks prevent double-processing on webhook retries.
- The webhook accepts only `POST` and rejects unsigned requests with `401`.

## Files added / modified

- `functions/package.json`, `tsconfig.json`, `.gitignore`
- `functions/src/paymongo.ts` — typed PayMongo client + webhook signature verification.
- `functions/src/index.ts` — `createCashInSource`, `createTaskQrPayment`, `paymongoWebhook`.
- `firebase.json` — registers the functions codebase.
- `lib/features/wallet/data/paymongo_service.dart` — Flutter callable client.
- `lib/features/wallet/presentation/widgets/merchant_qr_sheet.dart` — QR display + status stream.
- `lib/features/wallet/presentation/screens/cash_in_screen.dart` — wired to PayMongo for GCash/Maya.
- `lib/features/resident/presentation/screens/create_task_screen.dart` — Grocery > ₱200 routes through QR Ph.
- `lib/features/resident/data/resident_task_service.dart` — `publishTask` now mirrors to top-level `tasks/{id}` and returns the ref.
- `pubspec.yaml` — adds `cloud_functions`, `url_launcher`.
