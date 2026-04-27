import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

import {
  PaymongoClient,
  verifyWebhookSignature,
  type PaymongoSourceType,
} from "./paymongo";

initializeApp({
  projectId: process.env.GCLOUD_PROJECT ?? "kabayansync",
});
const db = getFirestore();

// Reads keys from environment variables. For local emulator runs, set them
// in functions/.env (gitignored). For Blaze deploys, prefer Secret Manager
// via `firebase functions:secrets:set` and switch back to defineSecret().
function paymongoSecretKey(): string {
  const v = process.env.PAYMONGO_SECRET_KEY;
  if (!v) throw new Error("PAYMONGO_SECRET_KEY env var is missing.");
  return v;
}

function paymongoWebhookSecret(): string {
  return process.env.PAYMONGO_WEBHOOK_SECRET ?? "";
}

const REGION = "asia-southeast1";
const ALLOWED_SOURCES: PaymongoSourceType[] = ["gcash", "grab_pay", "paymaya"];

function client(): PaymongoClient {
  return new PaymongoClient(paymongoSecretKey());
}

function pesosToCentavos(pesos: number): number {
  return Math.round(pesos * 100);
}

function centavosToPesos(centavos: number): number {
  return Math.round(centavos) / 100;
}

function requireAuth(uid: string | undefined): string {
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  return uid;
}

function resolveUid(req: { auth?: { uid?: string }; data?: unknown }): string {
  const authUid = req.auth?.uid;
  if (authUid) {
    return authUid;
  }

  const data = req.data;
  if (
    process.env.FUNCTIONS_EMULATOR === "true" &&
    data &&
    typeof data === "object" &&
    "userId" in data
  ) {
    const userId = (data as { userId?: unknown }).userId;
    if (typeof userId === "string" && userId.trim().length > 0) {
      return userId.trim();
    }
  }

  throw new HttpsError("unauthenticated", "Sign in required.");
}

function validateAmount(rawPesos: unknown, min: number): number {
  const pesos = typeof rawPesos === "number" ? rawPesos : Number(rawPesos);
  if (!Number.isFinite(pesos) || pesos < min) {
    throw new HttpsError(
      "invalid-argument",
      `Amount must be a number >= ${min}.`,
    );
  }
  return pesos;
}

/**
 * Create a PayMongo Source for wallet cash-in.
 * Resident pays via GCash/Maya/GrabPay redirect; balance credits on webhook.
 */
export const createCashInSource = onCall(
  { region: REGION },
  async (req) => {
    const uid = resolveUid(req);
    const data = req.data ?? {};
    const amount = validateAmount(data.amountPesos, 50);
    const type = (data.sourceType ?? "gcash") as PaymongoSourceType;
    if (!ALLOWED_SOURCES.includes(type)) {
      throw new HttpsError(
        "invalid-argument",
        `sourceType must be one of ${ALLOWED_SOURCES.join(", ")}.`,
      );
    }

    if (process.env.FUNCTIONS_EMULATOR === "true") {
      const sourceId = `mock_${Date.now()}`;
      const checkoutUrl = `https://example.com/kbsync/mock-checkout/${sourceId}`;

      await db
        .collection("users")
        .doc(uid)
        .collection("paymongo_sources")
        .doc(sourceId)
        .set({
          sourceId,
          type,
          amount,
          status: "paid",
          purpose: "wallet_cash_in",
          checkoutUrl,
          creditedAt: FieldValue.serverTimestamp(),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

      await db
        .collection("users")
        .doc(uid)
        .set(
          {
            walletBalance: FieldValue.increment(amount),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

      await db
        .collection("users")
        .doc(uid)
        .collection("wallet_transactions")
        .add({
          title: "Cash In",
          subtitle: `${prettySourceLabel(type)} Top-Up`,
          amount,
          isCredit: true,
          category: "cash_in",
          paymongoSourceId: sourceId,
          createdAt: FieldValue.serverTimestamp(),
        });

      return {
        sourceId,
        checkoutUrl,
        status: "paid",
      };
    }

    const successUrl =
      typeof data.successUrl === "string" && data.successUrl.length > 0
        ? data.successUrl
        : "kbsync://wallet/cash-in/success";
    const failedUrl =
      typeof data.failedUrl === "string" && data.failedUrl.length > 0
        ? data.failedUrl
        : "kbsync://wallet/cash-in/failed";

    const source = await client().createSource({
      amountCentavos: pesosToCentavos(amount),
      type,
      successUrl,
      failedUrl,
      description: `KaBayan Sync wallet cash in (${uid})`,
      metadata: {
        uid,
        purpose: "wallet_cash_in",
      },
    });

    await db
      .collection("users")
      .doc(uid)
      .collection("paymongo_sources")
      .doc(source.id)
      .set({
        sourceId: source.id,
        type,
        amount,
        status: source.status,
        purpose: "wallet_cash_in",
        checkoutUrl: source.checkoutUrl,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

    return {
      sourceId: source.id,
      checkoutUrl: source.checkoutUrl,
      status: source.status,
    };
  },
);

/**
 * Create a QR Ph PaymentIntent for grocery tasks where budget > ₱200.
 * Funds land in the platform PayMongo account (escrow); released on task completion.
 */
export const createTaskQrPayment = onCall(
  { region: REGION },
  async (req) => {
    const uid = resolveUid(req);
    const data = req.data ?? {};
    const amount = validateAmount(data.amountPesos, 201);
    const taskId = typeof data.taskId === "string" ? data.taskId : "";
    if (!taskId) {
      throw new HttpsError("invalid-argument", "taskId is required.");
    }

    if (process.env.FUNCTIONS_EMULATOR === "true") {
      const paymentIntentId = `mock_pi_${Date.now()}`;
      const qrCodeData = JSON.stringify({
        mode: "mock",
        taskId,
        amountPesos: amount,
        paymentIntentId,
      });

      await db
        .collection("users")
        .doc(uid)
        .collection("paymongo_intents")
        .doc(paymentIntentId)
        .set({
          intentId: paymentIntentId,
          taskId,
          amount,
          status: "paid",
          purpose: "task_qr_payment",
          qrCodeUrl: `https://example.com/kbsync/mock-qr/${paymentIntentId}`,
          qrCodeData,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

      return {
        paymentIntentId,
        qrCodeUrl: `https://example.com/kbsync/mock-qr/${paymentIntentId}`,
        qrCodeData,
        status: "paid",
      };
    }

    const intent = await client().createQrPayment({
      amountCentavos: pesosToCentavos(amount),
      description: `KaBayan Sync grocery task ${taskId}`,
      metadata: {
        uid,
        taskId,
        purpose: "task_qr_payment",
      },
    });

    await db
      .collection("users")
      .doc(uid)
      .collection("paymongo_intents")
      .doc(intent.paymentIntentId)
      .set({
        intentId: intent.paymentIntentId,
        taskId,
        amount,
        status: intent.status,
        purpose: "task_qr_payment",
        qrCodeUrl: intent.qrCodeUrl,
        qrCodeData: intent.qrCodeData,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

    return {
      paymentIntentId: intent.paymentIntentId,
      qrCodeUrl: intent.qrCodeUrl,
      qrCodeData: intent.qrCodeData,
      status: intent.status,
    };
  },
);

/**
 * PayMongo webhook receiver.
 * Configure in PayMongo dashboard:
 *   URL = https://<region>-<project>.cloudfunctions.net/paymongoWebhook
 *   Events: source.chargeable, payment.paid, payment.failed
 */
export const paymongoWebhook = onRequest(
  {
    region: REGION,
    cors: false,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const rawBody =
      (req as { rawBody?: Buffer }).rawBody?.toString("utf8") ??
      JSON.stringify(req.body);

    const signature = req.header("Paymongo-Signature");
    const ok = verifyWebhookSignature(
      signature,
      rawBody,
      paymongoWebhookSecret(),
    );
    if (!ok) {
      logger.warn("Invalid PayMongo webhook signature", { signature });
      res.status(401).send("Invalid signature");
      return;
    }

    const event = req.body?.data;
    const eventType: string = event?.attributes?.type ?? "";
    const payload = event?.attributes?.data;

    try {
      if (eventType === "source.chargeable") {
        await handleSourceChargeable(payload);
      } else if (eventType === "payment.paid") {
        await handlePaymentPaid(payload);
      } else if (eventType === "payment.failed") {
        await handlePaymentFailed(payload);
      } else {
        logger.info("Ignored PayMongo event", { eventType });
      }
      res.status(200).send("ok");
    } catch (err) {
      logger.error("Webhook handler failed", err as Error);
      res.status(500).send("handler error");
    }
  },
);

interface PaymongoSourcePayload {
  id: string;
  attributes?: {
    type?: string;
    amount?: number;
    metadata?: Record<string, string>;
  };
}

async function handleSourceChargeable(source: PaymongoSourcePayload | undefined) {
  if (!source?.id) return;
  const meta = source.attributes?.metadata ?? {};
  const uid = meta.uid;
  const purpose = meta.purpose;
  if (!uid || purpose !== "wallet_cash_in") return;

  const amountPesos = centavosToPesos(source.attributes?.amount ?? 0);
  const sourceRef = db
    .collection("users")
    .doc(uid)
    .collection("paymongo_sources")
    .doc(source.id);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(sourceRef);
    const existing = snap.data();
    if (existing?.creditedAt) {
      // already credited, skip
      return;
    }

    tx.set(
      sourceRef,
      {
        status: "chargeable",
        creditedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const userRef = db.collection("users").doc(uid);
    tx.set(
      userRef,
      {
        walletBalance: FieldValue.increment(amountPesos),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const txRef = userRef.collection("wallet_transactions").doc();
    const sourceType = source.attributes?.type ?? "paymongo";
    tx.set(txRef, {
      title: "Cash In",
      subtitle: `${prettySourceLabel(sourceType)} Top-Up`,
      amount: amountPesos,
      isCredit: true,
      category: "cash_in",
      paymongoSourceId: source.id,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
}

interface PaymongoPaymentPayload {
  id: string;
  attributes?: {
    amount?: number;
    metadata?: Record<string, string>;
    payment_intent_id?: string;
  };
}

async function handlePaymentPaid(payment: PaymongoPaymentPayload | undefined) {
  if (!payment?.id) return;
  const meta = payment.attributes?.metadata ?? {};
  const uid = meta.uid;
  const purpose = meta.purpose;
  const taskId = meta.taskId;
  if (!uid) return;

  const amountPesos = centavosToPesos(payment.attributes?.amount ?? 0);

  if (purpose === "task_qr_payment" && taskId) {
    const intentId = payment.attributes?.payment_intent_id;
    const userRef = db.collection("users").doc(uid);

    await db.runTransaction(async (tx) => {
      if (intentId) {
        const intentRef = userRef
          .collection("paymongo_intents")
          .doc(intentId);
        tx.set(
          intentRef,
          {
            status: "paid",
            paymentId: payment.id,
            paidAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      const taskRef = db.collection("tasks").doc(taskId);
      tx.set(
        taskRef,
        {
          escrow: {
            paymentId: payment.id,
            paymentIntentId: intentId ?? null,
            amount: amountPesos,
            status: "funded",
            fundedAt: FieldValue.serverTimestamp(),
          },
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
    return;
  }

  if (purpose === "wallet_cash_in") {
    // Cash-in via card / direct PaymentIntent (not source-based) — credit balance.
    const userRef = db.collection("users").doc(uid);
    await userRef.set(
      {
        walletBalance: FieldValue.increment(amountPesos),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await userRef.collection("wallet_transactions").add({
      title: "Cash In",
      subtitle: "Card Top-Up",
      amount: amountPesos,
      isCredit: true,
      category: "cash_in",
      paymongoPaymentId: payment.id,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
}

async function handlePaymentFailed(payment: PaymongoPaymentPayload | undefined) {
  if (!payment?.id) return;
  const meta = payment.attributes?.metadata ?? {};
  const uid = meta.uid;
  const taskId = meta.taskId;
  if (!uid) return;

  const intentId = payment.attributes?.payment_intent_id;
  if (intentId) {
    await db
      .collection("users")
      .doc(uid)
      .collection("paymongo_intents")
      .doc(intentId)
      .set(
        {
          status: "failed",
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
  }

  if (taskId) {
    await db.collection("tasks").doc(taskId).set(
      {
        escrow: {
          status: "failed",
          updatedAt: FieldValue.serverTimestamp(),
        },
      },
      { merge: true },
    );
  }
}

function prettySourceLabel(type: string): string {
  switch (type) {
    case "gcash":
      return "GCash";
    case "grab_pay":
      return "GrabPay";
    case "paymaya":
      return "Maya";
    default:
      return "PayMongo";
  }
}
