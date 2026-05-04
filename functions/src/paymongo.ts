import * as crypto from "crypto";

const PAYMONGO_BASE = "https://api.paymongo.com/v1";

export type PaymongoSourceType = "gcash" | "grab_pay" | "paymaya";

export interface CreateSourceArgs {
  amountCentavos: number;
  type: PaymongoSourceType;
  successUrl: string;
  failedUrl: string;
  description?: string;
  metadata?: Record<string, string>;
}

export interface PaymongoSourceResponse {
  id: string;
  status: string;
  checkoutUrl: string | null;
  raw: unknown;
}

export interface CreateQrPaymentArgs {
  amountCentavos: number;
  description: string;
  metadata?: Record<string, string>;
}

export interface PaymongoQrResponse {
  paymentIntentId: string;
  qrCodeUrl: string | null;
  qrCodeData: string | null;
  status: string;
  raw: unknown;
}

export class PaymongoClient {
  constructor(private readonly secretKey: string) {
    if (!secretKey) {
      throw new Error("PayMongo secret key missing");
    }
  }

  private authHeader(): string {
    return "Basic " + Buffer.from(this.secretKey + ":").toString("base64");
  }

  private async request<T = unknown>(
    method: "GET" | "POST",
    path: string,
    body?: unknown,
  ): Promise<T> {
    const res = await fetch(PAYMONGO_BASE + path, {
      method,
      headers: {
        Authorization: this.authHeader(),
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: body ? JSON.stringify(body) : undefined,
    });

    const text = await res.text();
    let parsed: unknown = null;
    try {
      parsed = text ? JSON.parse(text) : null;
    } catch {
      parsed = text;
    }

    if (!res.ok) {
      const err = new Error(
        `PayMongo ${method} ${path} failed: ${res.status} ${text}`,
      );
      (err as Error & { response?: unknown }).response = parsed;
      throw err;
    }

    return parsed as T;
  }

  async createSource(args: CreateSourceArgs): Promise<PaymongoSourceResponse> {
    const body = {
      data: {
        attributes: {
          amount: args.amountCentavos,
          currency: "PHP",
          type: args.type,
          redirect: {
            success: args.successUrl,
            failed: args.failedUrl,
          },
          ...(args.description ? { description: args.description } : {}),
          ...(args.metadata ? { metadata: args.metadata } : {}),
        },
      },
    };

    const json = await this.request<{
      data: {
        id: string;
        attributes: {
          status: string;
          redirect?: { checkout_url?: string };
        };
      };
    }>("POST", "/sources", body);

    return {
      id: json.data.id,
      status: json.data.attributes.status,
      checkoutUrl: json.data.attributes.redirect?.checkout_url ?? null,
      raw: json,
    };
  }

  async createQrPayment(
    args: CreateQrPaymentArgs,
  ): Promise<PaymongoQrResponse> {
    const body = {
      data: {
        attributes: {
          amount: args.amountCentavos,
          currency: "PHP",
          payment_method_allowed: ["qrph"],
          capture_type: "automatic",
          description: args.description,
          ...(args.metadata ? { metadata: args.metadata } : {}),
        },
      },
    };

    const json = await this.request<{
      data: {
        id: string;
        attributes: {
          status: string;
          next_action?: {
            type?: string;
            redirect?: { url?: string };
            qr_code?: { image_url?: string; data?: string };
          };
          qr_code?: { image_url?: string; data?: string };
        };
      };
    }>("POST", "/payment_intents", body);

    const next = json.data.attributes.next_action ?? {};
    const qr =
      json.data.attributes.qr_code ??
      next.qr_code ??
      undefined;

    return {
      paymentIntentId: json.data.id,
      qrCodeUrl: qr?.image_url ?? null,
      qrCodeData: qr?.data ?? null,
      status: json.data.attributes.status,
      raw: json,
    };
  }

  async retrieveSource(id: string): Promise<unknown> {
    return this.request("GET", `/sources/${id}`);
  }

  async retrievePaymentIntent(id: string): Promise<unknown> {
    return this.request("GET", `/payment_intents/${id}`);
  }

  async createPayout(args: {
    amountCentavos: number;
    method: string;
    recipient: string;
    description: string;
  }): Promise<unknown> {
    const body = {
      data: {
        attributes: {
          amount: args.amountCentavos,
          currency: "PHP",
          payout_method: {
            type: args.method, // "gcash", "maya", "bank_transfer"
            details: {
              account_number: args.recipient, // phone for GCash/Maya, account for bank
            },
          },
          description: args.description,
        },
      },
    };

    return this.request("POST", "/payouts", body);
  }
}

export function verifyWebhookSignature(
  signatureHeader: string | null | undefined,
  rawBody: string,
  webhookSecret: string,
): boolean {
  if (!signatureHeader || !webhookSecret) return false;
  const parts = signatureHeader.split(",").reduce<Record<string, string>>(
    (acc, part) => {
      const [k, v] = part.split("=");
      if (k && v) acc[k.trim()] = v.trim();
      return acc;
    },
    {},
  );
  const timestamp = parts["t"];
  const testSig = parts["te"];
  const liveSig = parts["li"];
  const provided = liveSig ?? testSig;
  if (!timestamp || !provided) return false;

  const computed = crypto
    .createHmac("sha256", webhookSecret)
    .update(`${timestamp}.${rawBody}`)
    .digest("hex");

  try {
    return crypto.timingSafeEqual(
      Buffer.from(computed, "hex"),
      Buffer.from(provided, "hex"),
    );
  } catch {
    return false;
  }
}
