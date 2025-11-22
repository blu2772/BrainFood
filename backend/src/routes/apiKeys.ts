import { Router, Request, Response } from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken } from "../middleware/auth";
import {
  createTemporaryApiKey,
  getUserApiKeys,
  deleteApiKey,
} from "../services/apiKeyService";

const router = Router();
const prisma = new PrismaClient();

/**
 * POST /api/api-keys
 * Erstellt einen neuen temporären API-Key (60 Minuten)
 */
router.post("/", authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;

    const { key, keyPrefix, expiresAt } = await createTemporaryApiKey(userId);

    res.status(201).json({
      key, // WICHTIG: Nur hier wird der ungehashte Key zurückgegeben!
      keyPrefix,
      expiresAt: expiresAt.toISOString(),
      message: "API key created. Save it now - it won't be shown again!",
    });
  } catch (error: any) {
    console.error("Create API key error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * GET /api/api-keys
 * Liefert alle API-Keys des aktuellen Benutzers (ohne den Key selbst)
 */
router.get("/", authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;

    const keys = await getUserApiKeys(userId);

    res.json({ keys });
  } catch (error: any) {
    console.error("Get API keys error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * DELETE /api/api-keys/:keyId
 * Löscht einen API-Key
 */
router.delete("/:keyId", authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { keyId } = req.params;

    const deleted = await deleteApiKey(keyId, userId);

    if (!deleted) {
      return res.status(404).json({ error: "API key not found" });
    }

    res.json({ message: "API key deleted successfully" });
  } catch (error: any) {
    console.error("Delete API key error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

export default router;

