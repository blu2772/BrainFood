import { PrismaClient } from "@prisma/client";
import crypto from "crypto";

const prisma = new PrismaClient();

/**
 * Generiert einen neuen API-Key
 */
export function generateApiKey(): string {
  // Generiere einen sicheren 32-Byte Key und konvertiere zu Base64
  const randomBytes = crypto.randomBytes(32);
  return `bf_${randomBytes.toString("base64url")}`;
}

/**
 * Hasht einen API-Key für sichere Speicherung
 */
export function hashApiKey(key: string): string {
  return crypto.createHash("sha256").update(key).digest("hex");
}

/**
 * Erstellt einen neuen temporären API-Key (60 Minuten)
 */
export async function createTemporaryApiKey(userId: string): Promise<{
  key: string;
  keyPrefix: string;
  expiresAt: Date;
}> {
  const key = generateApiKey();
  const keyHash = hashApiKey(key);
  const keyPrefix = key.substring(0, 12); // Erste 12 Zeichen für Anzeige
  
  // 60 Minuten ab jetzt
  const expiresAt = new Date();
  expiresAt.setMinutes(expiresAt.getMinutes() + 60);

  await prisma.apiKey.create({
    data: {
      userId,
      key: keyHash,
      keyPrefix,
      expiresAt,
    },
  });

  return {
    key, // Nur hier wird der ungehashte Key zurückgegeben
    keyPrefix,
    expiresAt,
  };
}

/**
 * Validiert einen API-Key und gibt den User zurück
 */
export async function validateApiKey(key: string): Promise<{
  userId: string;
  keyId: string;
} | null> {
  const keyHash = hashApiKey(key);

  const apiKey = await prisma.apiKey.findUnique({
    where: { key: keyHash },
    include: { user: true },
  });

  if (!apiKey) {
    return null;
  }

  // Prüfe ob abgelaufen
  if (apiKey.expiresAt < new Date()) {
    // Lösche abgelaufenen Key
    await prisma.apiKey.delete({
      where: { id: apiKey.id },
    });
    return null;
  }

  // Update lastUsedAt
  await prisma.apiKey.update({
    where: { id: apiKey.id },
    data: { lastUsedAt: new Date() },
  });

  return {
    userId: apiKey.userId,
    keyId: apiKey.id,
  };
}

/**
 * Löscht einen API-Key
 */
export async function deleteApiKey(keyId: string, userId: string): Promise<boolean> {
  const apiKey = await prisma.apiKey.findFirst({
    where: {
      id: keyId,
      userId,
    },
  });

  if (!apiKey) {
    return false;
  }

  await prisma.apiKey.delete({
    where: { id: keyId },
  });

  return true;
}

/**
 * Holt alle API-Keys eines Users
 */
export async function getUserApiKeys(userId: string) {
  return await prisma.apiKey.findMany({
    where: { userId },
    orderBy: { createdAt: "desc" },
    select: {
      id: true,
      keyPrefix: true,
      expiresAt: true,
      createdAt: true,
      lastUsedAt: true,
    },
  });
}

/**
 * Bereinigt abgelaufene API-Keys
 */
export async function cleanupExpiredKeys(): Promise<number> {
  const result = await prisma.apiKey.deleteMany({
    where: {
      expiresAt: {
        lt: new Date(),
      },
    },
  });

  return result.count;
}

