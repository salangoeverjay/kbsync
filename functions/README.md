createDefaultAdmin Cloud Function

This project exposes a callable Cloud Function `createDefaultAdmin` that will:
- Ensure `platform_accounts/platform` exists in Firestore
- Create a Firebase Auth user (if not present) and set custom claim `admin: true`

Usage


1) Set the secret in Secret Manager and optionally define default email/password in a local `.env` file:

```bash
firebase functions:secrets:set ADMIN_CREATE_SECRET
```

For the default admin email/password, add these to `functions/.env` or pass them in the function call:

```bash
ADMIN_DEFAULT_EMAIL=admin@example.com
ADMIN_DEFAULT_PASSWORD=S3cureP@ss
```

2) Deploy functions:

```bash
npm --prefix functions run build
firebase deploy --only functions
```

3) Call the function once to create the admin:

```bash
firebase functions:call createDefaultAdmin --data '{"secret":"MYSECRET","email":"admin@example.com","password":"S3cureP@ss"}'
```

Notes
- The function is idempotent: calling it repeatedly will not create duplicate admin users.
- For CI/CD deployments you can call this function from your deployment pipeline after a successful `firebase deploy`.

## No-Blaze alternative

If your Firebase project is on the Spark plan and you cannot use Secret Manager, use the local helper at `tools/create-admin/README.md` instead. It creates the admin user from your machine with the Firebase Admin SDK and does not require Blaze.
