# KA-BAYAN SYNC

## Hyper-Local Neighborhood Task Platform for Panabo City

---

## PROJECT BRIEF

### Pain Points & Solutions

#### 1. Identity Risk
- Residents hire unvetted individuals from social media or word-of-mouth.

**Solution: Biometric Identity Mapping**
- 5-second liveness face scan
- Cross-referenced with legal IDs (Student, National, Barangay)
- Ensures verified identity

---

#### 2. Accountability Gap
- Workers may fake completion using edited/old photos

**Solution: Camera Intent Lock & Evidence Integrity**
- No gallery uploads allowed
- Live capture only
- GPS + timestamp watermark
- AI image filtering + Moire detection

---

#### 3. Financial Risk
- Unsafe handling of cash (> ₱200)

**Solution: Secure Settlement Protocol**
- Hirer pays merchant directly via QR
- Worker acts only as courier

---

#### 4. Unreliable Labor
- No trust system for workers

**Solution: Dynamic Trust Score**
- Based on:
  - Completion history
  - GPS punctuality
  - Ratings

---

## TARGET MARKET

### Hirers
- Working professionals
- Elderly citizens
- Dual-income families

### Workers
- Students
- Stay-at-home parents
- Individuals in transition

---

## RISKS OF GOING OFFLINE

### Security
- No biometric or GPS logs outside app

### Financial
- Risk of scams (cash-based)

### Reputation
- No trust score growth

---

## REVENUE MODEL

### 10% Service Fee
- Deducted from worker earnings

### Kabayan Trust Bond
- Minimum ₱30 wallet balance

### Account Restrictions
- Below ₱10 → Ineligible
- Negative → Account locked

---

## SERVICE SCOPE

- Pabili (grocery)
- Dishwashing
- Laundry
- House cleaning

---

## SYSTEM LIMITATIONS

- 2km radius (Panabo City only)
- Requires smartphone + GPS + internet
- No licensed work (plumbing, etc.)

---

## WORKER PROBATION

- First 5 tasks = Rookie
- Cannot accept Pabili
- Must complete tasks to unlock full access

---

# OVERVIEW

## Problem
- Informal hiring = unsafe + inefficient

## Solution
KA-BAYAN SYNC provides:
- Biometric verification
- GPS tracking
- Digital payments
- Reputation system

---

## CORE FEATURES

### Biometric Verification
- Entrance + Exit scans
- Entrance scan is mandatory before worker can start task
- Exit scan is mandatory before worker can complete task and trigger payment

### GPS Tracking
- Real-time presence validation

### Trust Score
- Data-driven worker reputation

### Payment System
- Cash + GCash support

---

## SYSTEM WORKFLOW

### Task Flow
1. Hirer posts task
2. Worker accepts
3. Entrance scan
4. Task execution
5. Evidence capture
6. Exit scan
7. Payment

Enforcement:
- `Start Task` remains locked until entrance biometric scan passes
- `Finish Task` remains locked until exit biometric scan passes

---

## SECURITY FEATURES

- Camera Intent Lock
- GPS watermarking
- Screen detection firewall
- Encrypted audit logs

---

## PABILI PROTOCOL

### Under ₱200
- Cash allowed
- Must take “Funds Received” photo

### Over ₱200
- Direct merchant payment via QR

---

## FAIL-SAFES

- 1% battery → location ping
- 30-minute dispute window
- Auto-verify system

---

## WORKER PROCESS

1. Upload ID + face scan
2. Maintain ₱30 wallet
3. Go online (GPS enabled)
4. Accept tasks
5. Perform Entrance Scan
6. Do task + capture proof
7. Exit Scan
8. Receive payment

---

## HIRER PROCESS

1. Check nearby workers
2. Post task (attach a reference photo and specify what/where to clean, dish count, or laundry load)
3. Choose Standard or Rush
4. Monitor worker GPS
5. Verify work
6. Pay + rate worker

---

## COMPETITOR COMPARISON

| Feature | KA-BAYAN SYNC | Grab | MyKuya | GoodWork |
|--------|--------------|------|--------|---------|
| Focus | Local chores | Delivery | Assistants | Skilled work |
| Identity | Face scan per task | Login | Manual | Background check |
| Radius | 2km | City-wide | City-wide | City-wide |
| Proof | GPS + photos | GPS only | Chat | Report |

---

## KEY ADVANTAGE

- Hyper-local trust system
- Real-time verification
- Financial safety protocols

## HOW TO RUN
- cd backend/id_verifier_api
- dart run bin/server.dart
- cd c:\Users\salan\OneDrive\Documents\kbsync
- firebase emulators:start --only functions
- flutter run --dart-define=KBSYNC_ID_VERIFIER_API_BASE_URL=http://192.168.254.100:8080 --dart-define=KBSYNC_USE_FUNCTIONS_EMULATOR=true --dart-define=KBSYNC_FUNCTIONS_EMULATOR_HOST=192.168.254.100 --dart-define=KBSYNC_FUNCTIONS_EMULATOR_PORT=5001            

### If Gradle Fails With an Immutable Kotlin DSL Workspace Error
- Stop any running Gradle daemons with `gradlew --stop` from the project root.
- Delete the affected cache under `C:\Users\salan\.gradle\caches\8.14\kotlin-dsl\scripts\` if the error names a specific workspace directory.
- Run `flutter clean` and try `flutter run` again.
