const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function readServiceAccount() {
  const envPath = process.env.SERVICE_ACCOUNT_PATH;
  const googlePath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const cliPath = process.argv[4];
  const candidatePath = envPath
    ? path.resolve(envPath)
    : cliPath
      ? path.resolve(cliPath)
      : googlePath
        ? path.resolve(googlePath)
        : path.resolve(__dirname, 'serviceAccountKey.json');

  if (!fs.existsSync(candidatePath)) {
    throw new Error(
      `Service account key not found at ${candidatePath}. Set SERVICE_ACCOUNT_PATH, GOOGLE_APPLICATION_CREDENTIALS, pass a 4th CLI arg, or place serviceAccountKey.json in tools/create-admin/.`,
    );
  }

  return require(candidatePath);
}

async function main() {
  const email = process.argv[2];
  const password = process.argv[3];

  if (!email || !password) {
    console.error('Usage: node create_admin.js <email> <password> [serviceAccountPath]');
    process.exit(1);
  }

  const serviceAccount = readServiceAccount();
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  const auth = admin.auth();
  let userRecord;

  try {
    userRecord = await auth.getUserByEmail(email);
    await auth.updateUser(userRecord.uid, { password });
  } catch (error) {
    if (error && error.code !== 'auth/user-not-found') {
      throw error;
    }
    userRecord = await auth.createUser({ email, password });
  }

  await auth.setCustomUserClaims(userRecord.uid, { admin: true });

  console.log(JSON.stringify({ createdOrUpdated: true, uid: userRecord.uid, email }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});