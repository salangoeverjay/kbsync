const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function readServiceAccount() {
  const envPath = process.env.SERVICE_ACCOUNT_PATH;
  const googlePath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const cliPath = process.argv[3];
  const candidatePath = envPath
    ? path.resolve(envPath)
    : cliPath
      ? path.resolve(cliPath)
      : googlePath
        ? path.resolve(googlePath)
        : path.resolve(__dirname, 'serviceAccountKey.json');

  if (!fs.existsSync(candidatePath)) {
    throw new Error(
      `Service account key not found at ${candidatePath}. Set SERVICE_ACCOUNT_PATH, GOOGLE_APPLICATION_CREDENTIALS, pass a CLI arg, or place serviceAccountKey.json in tools/create-admin/.`,
    );
  }

  return require(candidatePath);
}

async function main() {
  const email = process.argv[2];
  if (!email) {
    console.error('Usage: node set_verified.js <email> [serviceAccountPath]');
    process.exit(1);
  }

  const serviceAccount = readServiceAccount();
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const auth = admin.auth();

  try {
    const user = await auth.getUserByEmail(email);
    await auth.updateUser(user.uid, { emailVerified: true });
    console.log(JSON.stringify({ email: user.email, uid: user.uid, emailVerified: true }, null, 2));
  } catch (err) {
    console.error('Failed to set emailVerified:', err);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
