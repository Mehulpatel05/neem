import fetch from "node-fetch";

export interface WakitSendOtpResponse {
  success: boolean;
  data?: {
    id: string;
    to: string;
    status: string;
    channel?: string;
    expires_at?: string;
    created_at?: string;
  };
  request_id?: string;
  message?: string;
  error?: string;
}

export interface WakitVerifyOtpResponse {
  success: boolean;
  data?: {
    id: string;
    to: string;
    verified: boolean;
    status: string;
  };
  verified?: boolean;
  message?: string;
  error?: string;
}

export class WakitService {
  private readonly apiKey: string;
  private readonly baseUrl: string;

  constructor(apiKey: string, baseUrl: string) {
    this.apiKey = apiKey;
    // Normalize base URL so it points to https://wakit.in (without /api/v1 or trailing slashes)
    let cleaned = baseUrl.trim().replace(/\/+$/, "");
    cleaned = cleaned.replace(/\/api\/v1\/?$/, "");
    if (cleaned.includes("app.wakit.in")) {
      cleaned = cleaned.replace("app.wakit.in", "wakit.in");
    }
    this.baseUrl = cleaned || "https://wakit.in";
  }

  async requestOtp(phoneNumber: string): Promise<string> {
    const normalized = this.normalizePhone(phoneNumber);
    const endpoint = `${this.baseUrl}/api/v1/otp/send`;

    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        to: normalized,
        code_length: 6,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Wakit request OTP failed (${response.status}): ${errorText}`);
    }

    const json = (await response.json()) as WakitSendOtpResponse;

    const id = json.data?.id ?? json.request_id;
    if (!json.success || !id) {
      throw new Error(
        `Wakit request OTP returned no id: ${json.error ?? json.message ?? JSON.stringify(json)}`
      );
    }

    return id;
  }

  async verifyOtp(requestId: string, otp: string): Promise<boolean> {
    const endpoint = `${this.baseUrl}/api/v1/otp/verify`;

    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        id: requestId,
        code: otp,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Wakit verify OTP failed (${response.status}): ${errorText}`);
    }

    const json = (await response.json()) as WakitVerifyOtpResponse;

    if (json.data && typeof json.data.verified === "boolean") {
      return json.data.verified;
    }

    return json.success === true && json.verified === true;
  }

  private normalizePhone(phoneNumber: string): string {
    let normalized = phoneNumber.replace(/[\s\-()]+/g, "");
    if (!normalized.startsWith("+")) {
      if (normalized.startsWith("91") && normalized.length === 12) {
        normalized = `+${normalized}`;
      } else {
        normalized = `+91${normalized}`;
      }
    }
    return normalized;
  }
}
