import fetch from "node-fetch";

export interface WakitRequestOtpResponse {
  success: boolean;
  request_id?: string;
  message?: string;
  error?: string;
}

export interface WakitVerifyOtpResponse {
  success: boolean;
  verified?: boolean;
  message?: string;
  error?: string;
}

export class WakitService {
  private readonly apiKey: string;
  private readonly baseUrl: string;

  constructor(apiKey: string, baseUrl: string) {
    this.apiKey = apiKey;
    this.baseUrl = baseUrl.replace(/\/$/, "");
  }

  async requestOtp(phoneNumber: string): Promise<string> {
    const normalized = this.normalizePhone(phoneNumber);
    const response = await fetch(`${this.baseUrl}/api/v1/otp/request`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ phone_number: normalized }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Wakit request OTP failed (${response.status}): ${errorText}`);
    }

    const json = (await response.json()) as WakitRequestOtpResponse;

    if (!json.success || !json.request_id) {
      throw new Error(`Wakit request OTP returned no request_id: ${json.error ?? json.message ?? "unknown error"}`);
    }

    return json.request_id;
  }

  async verifyOtp(requestId: string, otp: string): Promise<boolean> {
    const response = await fetch(`${this.baseUrl}/api/v1/otp/verify`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ request_id: requestId, otp }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Wakit verify OTP failed (${response.status}): ${errorText}`);
    }

    const json = (await response.json()) as WakitVerifyOtpResponse;

    return json.success === true && json.verified === true;
  }

  private normalizePhone(phoneNumber: string): string {
    let normalized = phoneNumber.replace(/\s+/g, "");
    if (!normalized.startsWith("+")) {
      if (normalized.startsWith("91")) {
        normalized = `+${normalized}`;
      } else {
        normalized = `+91${normalized}`;
      }
    }
    return normalized;
  }
}
