# Local Admin Creator

This helper lets you create a Firebase admin user without Blaze or Secret Manager.

## What it does

- Creates the Firebase Auth user if it does not exist
- Updates the password if the user already exists
- Sets `admin: true` custom claim

## Setup

1. Copy your Firebase service account key JSON into this folder as `serviceAccountKey.json`, or set `SERVICE_ACCOUNT_PATH` to point to it.
	You can also pass the path as a 4th argument or set `GOOGLE_APPLICATION_CREDENTIALS`.
2. Install dependencies:

```powershell
npm install
```

## Run

```powershell
node create_admin.js admin@example.com S3cureP@ss
```

With an explicit key path:

```powershell
node create_admin.js admin@example.com S3cureP@ss C:\path\to\serviceAccountKey.json
```

If your key is stored elsewhere:

```powershell
$env:SERVICE_ACCOUNT_PATH = 'C:\path\to\serviceAccountKey.json'
node create_admin.js admin@example.com S3cureP@ss
```

## Notes

- Do not commit `serviceAccountKey.json` to source control.
- If you want to change the admin later, run the script again with the same email and a new password.