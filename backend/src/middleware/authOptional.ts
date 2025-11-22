import { Request, Response, NextFunction } from "express";
import { verifyToken, extractTokenFromHeader } from "../utils/jwt";
import { validateApiKey } from "../services/apiKeyService";

/**
 * Kombinierte Authentifizierung: Akzeptiert sowohl JWT als auch API-Key
 * Versucht zuerst JWT, dann API-Key
 */
export function authenticateTokenOrApiKey(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const authHeader = req.headers.authorization;
  
  // Versuche JWT zuerst
  const token = extractTokenFromHeader(authHeader);
  if (token) {
    try {
      const payload = verifyToken(token);
      (req as any).userId = payload.userId;
      (req as any).userEmail = payload.email;
      (req as any).authType = "jwt";
      next();
      return;
    } catch (error) {
      // JWT ungültig, versuche API-Key
    }
  }

  // Versuche API-Key
  let apiKey: string | null = null;
  if (authHeader && authHeader.startsWith("Bearer ")) {
    apiKey = authHeader.substring(7);
  } else if (req.headers["x-api-key"]) {
    apiKey = req.headers["x-api-key"] as string;
  }

  if (apiKey) {
    validateApiKey(apiKey)
      .then((result) => {
        if (!result) {
          res.status(401).json({ error: "Invalid or expired API key" });
          return;
        }
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
    return;
  }

  // Keine gültige Authentifizierung gefunden
  res.status(401).json({ error: "Authentication required (JWT token or API key)" });
  return;
}

