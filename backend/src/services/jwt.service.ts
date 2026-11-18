import jwt, { SignOptions, VerifyOptions, Secret } from "jsonwebtoken";
import bcrypt from "bcryptjs";
import { D1Service } from "./d1.service";

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export interface JWTPayload {
  sub: string;
  phoneNumber?: string;
  type: "access" | "refresh";
  iat?: number;
  exp?: number;
}

export class JWTService {
  private readonly accessSecret: Secret;
  private readonly refreshSecret: Secret;
  private readonly accessExpiresIn: string;
  private readonly refreshExpiresIn: string;
  private readonly d1: D1Service;

  constructor(
    accessSecret: string,
    refreshSecret: string,
    accessExpiresIn: string,
    refreshExpiresIn: string,
    d1: D1Service
  ) {
    this.accessSecret = accessSecret;
    this.refreshSecret = refreshSecret;
    this.accessExpiresIn = accessExpiresIn;
    this.refreshExpiresIn = refreshExpiresIn;
    this.d1 = d1;
  }

  signAccessToken(payload: Omit<JWTPayload, "type" | "iat" | "exp">): string {
    const accessPayload: JWTPayload = {
      sub: payload.sub,
      phoneNumber: payload.phoneNumber,
      type: "access",
    };
    return jwt.sign(accessPayload, this.accessSecret, {
      expiresIn: this.accessExpiresIn,
    } as SignOptions);
  }

  signRefreshToken(payload: Omit<JWTPayload, "type" | "iat" | "exp">): string {
    const refreshPayload: JWTPayload = {
      sub: payload.sub,
      phoneNumber: payload.phoneNumber,
      type: "refresh",
    };
    return jwt.sign(refreshPayload, this.refreshSecret, {
      expiresIn: this.refreshExpiresIn,
    } as SignOptions);
  }

  verifyAccessToken(token: string): JWTPayload {
    return jwt.verify(token, this.accessSecret, {
      algorithms: ["HS256"],
    } as VerifyOptions) as JWTPayload;
  }

  verifyRefreshToken(token: string): JWTPayload {
    return jwt.verify(token, this.refreshSecret, {
      algorithms: ["HS256"],
    } as VerifyOptions) as JWTPayload;
  }

  async hashToken(token: string): Promise<string> {
    return bcrypt.hash(token, 12);
  }

  async compareToken(token: string, hash: string): Promise<boolean> {
    return bcrypt.compare(token, hash);
  }

  async createSession(
    userId: string,
    accessToken: string,
    refreshToken: string,
    expiresInSeconds: number
  ): Promise<void> {
    const tokenHash = await this.hashToken(accessToken);
    const refreshTokenHash = await this.hashToken(refreshToken);
    const expiresAt = new Date(Date.now() + expiresInSeconds * 1000).toISOString();

    await this.d1.run(
      `INSERT INTO sessions (id, user_id, token_hash, refresh_token_hash, expires_at, created_at)
       VALUES (lower(hex(randomblob(16))), ?, ?, ?, ?, datetime('now'))
       ON CONFLICT(id) DO NOTHING`,
      [userId, tokenHash, refreshTokenHash, expiresAt]
    );
  }

  async validateSession(userId: string, accessToken: string): Promise<boolean> {
    const row = await this.d1.prepare(
      `SELECT token_hash FROM sessions WHERE user_id = ? AND expires_at > datetime('now') ORDER BY created_at DESC LIMIT 1`
    )
      .bind(userId)
      .first();

    if (!row || !(row as Record<string, unknown>).token_hash) {
      return false;
    }

    return this.compareToken(accessToken, String((row as Record<string, unknown>).token_hash));
  }

  async revokeSession(userId: string): Promise<void> {
    await this.d1.run(
      `DELETE FROM sessions WHERE user_id = ?`,
      [userId]
    );
  }

  async refreshAccessToken(refreshToken: string): Promise<{ accessToken: string; userId: string }> {
    const payload = this.verifyRefreshToken(refreshToken);
    const userId = payload.sub;

    const row = await this.d1.prepare(
      `SELECT refresh_token_hash, expires_at FROM sessions WHERE user_id = ? AND expires_at > datetime('now') ORDER BY created_at DESC LIMIT 1`
    )
      .bind(userId)
      .first();

    if (!row) {
      throw new Error("No valid session found for refresh");
    }

    const isValid = await this.compareToken(refreshToken, String((row as Record<string, unknown>).refresh_token_hash));
    if (!isValid) {
      throw new Error("Invalid refresh token");
    }

    const accessToken = this.signAccessToken({ sub: userId } as Omit<JWTPayload, "type" | "iat" | "exp">);

    const tokenHash = await this.hashToken(accessToken);
    await this.d1.run(
      `UPDATE sessions SET token_hash = ?, expires_at = datetime('now', '+15 minutes') WHERE user_id = ?`,
      [tokenHash, userId]
    );

    return { accessToken, userId };
  }
}
