import * as functions from 'firebase-functions';
import { defineSecret, defineString } from 'firebase-functions/params';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

const firestore = getFirestore();
const auth = getAuth();
const ADMIN_CREATE_SECRET = defineSecret('ADMIN_CREATE_SECRET');
const ADMIN_DEFAULT_EMAIL = defineString('ADMIN_DEFAULT_EMAIL', {
  default: 'admin@example.com',
});
const ADMIN_DEFAULT_PASSWORD = defineString('ADMIN_DEFAULT_PASSWORD', {
  default: 'S3cureP@ss',
});

function safeParamValue(param: { value: () => string }): string | undefined {
  try {
    const value = param.value();
    return typeof value === 'string' && value.length > 0 ? value : undefined;
  } catch {
    return undefined;
  }
}

export const createDefaultAdmin = functions.https.onCall(
  { secrets: [ADMIN_CREATE_SECRET] },
  async (data: any) => {
    const requiredSecret = safeParamValue(ADMIN_CREATE_SECRET);
    const providedSecret = data?.secret as string | undefined;

    if (requiredSecret && providedSecret !== requiredSecret) {
      throw new functions.https.HttpsError('permission-denied', 'Missing or invalid secret');
    }

    const email = (data?.email as string | undefined) ?? safeParamValue(ADMIN_DEFAULT_EMAIL);
    const password = (data?.password as string | undefined) ?? safeParamValue(ADMIN_DEFAULT_PASSWORD);

    if (!email || !password) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'email and password must be provided either via data or defaults',
      );
    }

    const platformRef = firestore.collection('platform_accounts').doc('platform');
    await platformRef.set(
      {
        balance: 0,
        currency: 'PHP',
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    try {
      const userRecord = await auth.getUserByEmail(email);
      await auth.setCustomUserClaims(userRecord.uid, { admin: true });
      return { created: false, uid: userRecord.uid, email };
    } catch (error: any) {
      if (error?.code !== 'auth/user-not-found') {
        throw new functions.https.HttpsError('internal', error?.message || String(error));
      }

      const createdUser = await auth.createUser({ email, password });
      await auth.setCustomUserClaims(createdUser.uid, { admin: true });
      return { created: true, uid: createdUser.uid, email };
    }
  },
);
