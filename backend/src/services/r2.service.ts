import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
  ListObjectsV2Command,
  DeleteObjectCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

export interface R2FileInfo {
  key: string;
  size: number;
  lastModified?: Date;
  url: string;
}

export class R2Service {
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly publicUrl: string;

  constructor(
    accountId: string,
    accessKeyId: string,
    secretAccessKey: string,
    bucket: string,
    publicUrl: string
  ) {
    this.client = new S3Client({
      region: "auto",
      endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
    });
    this.bucket = bucket;
    this.publicUrl = publicUrl.replace(/\/$/, "");
  }

  getUserKey(userId: string, folder: string, filename: string): string {
    const cleanFolder = folder.replace(/^\/+|\/+$/g, "");
    const cleanFilename = filename.replace(/^\/+/, "");
    return `users/${userId}/${cleanFolder}/${cleanFilename}`;
  }

  async putObject(
    key: string,
    body: Buffer | Uint8Array | string,
    contentType: string = "application/octet-stream"
  ): Promise<string> {
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      Body: typeof body === "string" ? Buffer.from(body, "utf-8") : body,
      ContentType: contentType,
    });
    await this.client.send(command);
    return this.getPublicUrl(key);
  }

  async getObject(key: string): Promise<{ data: Buffer; contentType: string }> {
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: key,
    });
    const response = await this.client.send(command);
    const streamToBuffer = async (stream: any): Promise<Buffer> => {
      const chunks: Buffer[] = [];
      for await (const chunk of stream) {
        chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
      }
      return Buffer.concat(chunks);
    };
    const data = await streamToBuffer(response.Body);
    return {
      data,
      contentType: response.ContentType ?? "application/octet-stream",
    };
  }

  async listUserFiles(userId: string, subfolder?: string): Promise<R2FileInfo[]> {
    const prefix = subfolder
      ? `users/${userId}/${subfolder.replace(/^\/+|\/+$/g, "")}/`
      : `users/${userId}/`;

    const command = new ListObjectsV2Command({
      Bucket: this.bucket,
      Prefix: prefix,
    });

    const response = await this.client.send(command);
    if (!response.Contents) return [];

    return response.Contents.map((item) => ({
      key: item.Key ?? "",
      size: item.Size ?? 0,
      lastModified: item.LastModified,
      url: this.getPublicUrl(item.Key ?? ""),
    }));
  }

  async deleteObject(key: string): Promise<void> {
    const command = new DeleteObjectCommand({
      Bucket: this.bucket,
      Key: key,
    });
    await this.client.send(command);
  }

  async getPresignedUploadUrl(
    key: string,
    contentType: string,
    expiresIn: number = 300
  ): Promise<{ url: string; key: string; publicUrl: string }> {
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: contentType,
    });
    const url = await getSignedUrl(this.client, command, { expiresIn });
    return { url, key, publicUrl: this.getPublicUrl(key) };
  }

  async getPresignedDownloadUrl(key: string, expiresIn: number = 300): Promise<string> {
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: key,
    });
    return getSignedUrl(this.client, command, { expiresIn });
  }

  getPublicUrl(key: string): string {
    if (this.publicUrl && !this.publicUrl.includes("cloudflarestorage.com")) {
      return `${this.publicUrl}/${key}`;
    }
    return `http://43.204.215.17/storage/${key}`;
  }
}
