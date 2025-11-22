import { Request, Response, NextFunction } from "express";
import { validateApiKey } from "../services/apiKeyService";

/**
 * Express Middleware zur Authentifizierung mit API-Key
 * Prüft den API-Key im Authorization-Header oder X-API-Key Header
 */
export function authenticateApiKey(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  // Prüfe Authorization Header (Bearer <key>)
  const authHeader = req.headers.authorization;
  let apiKey: string | null = null;

  if (authHeader && authHeader.startsWith("Bearer ")) {
    apiKey = authHeader.substring(7);
  } else if (req.headers["x-api-key"]) {
    // Alternative: X-API-Key Header
    apiKey = req.headers["x-api-key"] as string;
  }

  if (!apiKey) {
    res.status(401).json({ error: "API key required" });
    return;
  }

  // Validiere API-Key
  validateApiKey(apiKey)
    .then((result) => {
      if (!result) {
        res.status(401).json({ error: "Invalid or expired API key" });
        return;
      }

      // User-ID zum Request hinzufügen
      (req as any).userId = result.userId;
      (req as any).apiKeyId = result.keyId;
      (req as any).authType = "apiKey";
      next();
    })
    .catch((error) => {
      console.error("API key validation error:", error);
      res.status(500).json({ error: "Internal server error" });
      return;
    });
}

