import fetch from "node-fetch";

export interface D1QueryResult {
  success: boolean;
  results: unknown[];
  meta: {
    duration: number;
    size: number;
    rows_read: number;
    rows_written: number;
  };
}

export interface D1BatchResult {
  success: boolean;
  results: D1QueryResult[];
}

export class D1Service {
  private readonly baseUrl: string;
  private readonly apiToken: string;

  constructor(accountId: string, databaseId: string, apiToken: string) {
    let accId = accountId || process.env.D1_ACCOUNT_ID || "";
    let dbId = databaseId || process.env.D1_DATABASE_ID || "";
    const dbUrl = process.env.D1_DATABASE_URL || "";

    if (!dbId && dbUrl) {
      const match = dbUrl.match(/database\/([a-f0-9-]+)/i);
      if (match) dbId = match[1];
    }
    if (!accId && dbUrl) {
      const match = dbUrl.match(/accounts\/([a-f0-9]+)/i);
      if (match) accId = match[1];
    }

    this.baseUrl = `https://api.cloudflare.com/client/v4/accounts/${accId}/d1/database/${dbId}`;
    this.apiToken = apiToken || process.env.D1_API_TOKEN || "";
  }

  private headers(): Record<string, string> {
    return {
      Authorization: `Bearer ${this.apiToken}`,
      "Content-Type": "application/json",
    };
  }

  async execute(sql: string, params: unknown[] = []): Promise<D1QueryResult> {
    const response = await fetch(`${this.baseUrl}/query`, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({ sql, params }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`D1 query failed (${response.status}): ${errorText}`);
    }

    const json = (await response.json()) as {
      success: boolean;
      errors?: unknown[];
      messages?: unknown[];
      result: D1QueryResult[];
    };

    if (!json.success || !json.result?.[0]) {
      throw new Error(`D1 query returned no result: ${JSON.stringify(json.errors)}`);
    }

    return json.result[0];
  }

  async run(sql: string, params: unknown[] = []): Promise<D1QueryResult> {
    return this.execute(sql, params);
  }

  async batch(sqlStatements: Array<{ sql: string; params?: unknown[] }>): Promise<D1BatchResult> {
    const response = await fetch(`${this.baseUrl}/batch`, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({
        statements: sqlStatements.map((s) => ({ sql: s.sql, params: s.params ?? [] })),
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`D1 batch failed (${response.status}): ${errorText}`);
    }

    const json = (await response.json()) as {
      success: boolean;
      errors?: unknown[];
      messages?: unknown[];
      result: D1QueryResult[];
    };

    return {
      success: json.success,
      results: json.result,
    };
  }

  prepare(sql: string): D1PreparedStatement {
    return new D1PreparedStatement(this, sql);
  }
}

export class D1PreparedStatement {
  private readonly service: D1Service;
  private readonly sql: string;
  private params: unknown[] = [];

  constructor(service: D1Service, sql: string) {
    this.service = service;
    this.sql = sql;
  }

  bind(...params: unknown[]): this {
    this.params = params;
    return this;
  }

  async first(): Promise<unknown | null> {
    const result = await this.service.execute(this.sql, this.params);
    if (result.results.length === 0) return null;
    return result.results[0];
  }

  async all(): Promise<unknown[]> {
    const result = await this.service.execute(this.sql, this.params);
    return result.results;
  }

  async run(): Promise<D1QueryResult> {
    return this.service.execute(this.sql, this.params);
  }
}
