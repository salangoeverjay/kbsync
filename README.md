# KBSYNC

KBSYNC is a Flutter app with a Dart backend relay for Didit standalone APIs.

Current verification flow:
1. ID document verification
2. Passive liveness
3. Face match
4. Verification result UI

## Run On Physical Phone (Backend + App)

This guide is for Windows + real Android/iOS device connected to the same Wi-Fi as your PC.

## Prerequisites

1. Flutter SDK installed and working.
2. Dart SDK available (bundled with Flutter is fine).
3. A valid Didit API key.
4. Physical phone and PC on the same local network.

## 1) Find Your PC LAN IP

Run this in PowerShell:

```powershell
ipconfig
```

Use your IPv4 address from the active adapter, for example `192.168.254.100`.

## 2) Start The Backend API (Didit Relay)

Open terminal A:

```powershell
Set-Location C:\Users\salan\Documents\kbsync\backend\id_verifier_api
dart pub get
$env:DIDIT_API_KEY="YOUR_DIDIT_API_KEY"
dart run bin/server.dart
```

Expected output includes:

```text
id_verifier_api listening on http://0.0.0.0:8080
```

Notes:
1. `DIDIT_API_KEY` must be set in the same terminal session where the backend starts.
2. If backend says missing key, re-run the `$env:DIDIT_API_KEY=...` line and start again.

## 3) Allow Windows Firewall For Port 8080 (If Needed)

If your phone cannot reach backend, run PowerShell as Admin:

```powershell
New-NetFirewallRule -DisplayName "KBSYNC Backend 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
```

## 4) Run The Flutter App Pointing To Your Backend

Open terminal B:

```powershell
Set-Location C:\Users\salan\Documents\kbsync
flutter pub get
flutter run --dart-define=KBSYNC_ID_VERIFIER_API_BASE_URL=http://192.168.254.100:8080
```

Replace `192.168.254.100` with your actual PC LAN IP.

## 5) Quick Connectivity Test

From your PC:

```powershell
Invoke-WebRequest http://127.0.0.1:8080/health
```

Expected JSON response contains:

```json
{"ok":true}
```

If app still cannot connect from phone:
1. Confirm phone and PC are on same Wi-Fi.
2. Confirm backend is still running in terminal A.
3. Re-check LAN IP from `ipconfig`.
4. Confirm firewall rule allows 8080.

## Optional: One Command Launcher

This command starts backend in a new terminal and runs Flutter with your LAN URL:

```powershell
$k='YOUR_DIDIT_API_KEY'; $u='http://192.168.254.100:8080'; Start-Process powershell -ArgumentList '-NoExit','-Command',"`$env:DIDIT_API_KEY='$k'; Set-Location 'C:\Users\salan\Documents\kbsync\backend\id_verifier_api'; dart run bin/server.dart"; Set-Location 'C:\Users\salan\Documents\kbsync'; flutter run --dart-define=KBSYNC_ID_VERIFIER_API_BASE_URL=$u
```

Update:
1. `YOUR_DIDIT_API_KEY`
2. `192.168.254.100`

## Emulator URL Reminder

If using Android emulator instead of physical phone, use:

```text
http://10.0.2.2:8080
```
