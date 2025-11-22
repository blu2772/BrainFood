import { Router, Request, Response } from "express";
import { PrismaClient } from "@prisma/client";
import { hashPassword, verifyPassword } from "../utils/password";
import { generateToken } from "../utils/jwt";
import { authenticateToken } from "../middleware/auth";

const router = Router();
const prisma = new PrismaClient();

/**
 * POST /api/auth/register
 * Registriert einen neuen Benutzer
 */
router.post("/register", async (req: Request, res: Response) => {
  try {
    console.log("Registration attempt:", { email: req.body.email, name: req.body.name });
    
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ error: "Name, email and password are required" });
    }

    if (password.length < 6) {
      return res.status(400).json({ error: "Password must be at least 6 characters" });
    }

    console.log("Checking if user exists...");
    // Prüfe, ob E-Mail bereits existiert
    const existingUser = await prisma.user.findUnique({
      where: { email },
    });

    if (existingUser) {
      return res.status(409).json({ error: "Email already registered" });
    }

    console.log("Hashing password...");
    // Passwort hashen
    const passwordHash = await hashPassword(password);

    console.log("Creating user...");
    // Benutzer erstellen
    const user = await prisma.user.create({
      data: {
        name,
        email,
        passwordHash,
      },
      select: {
        id: true,
        name: true,
        email: true,
        createdAt: true,
      },
    });

    console.log("User created, generating token...");
    // JWT-Token generieren
    const token = generateToken({
      userId: user.id,
      email: user.email,
    });

    console.log("Registration successful");
    res.status(201).json({
      user,
      token,
    });
  } catch (error: any) {
    console.error("Registration error:", error);
    console.error("Error name:", error.name);
    console.error("Error message:", error.message);
    console.error("Error code:", error.code);
    console.error("Error stack:", error.stack);
    
    res.status(500).json({ 
      error: "Internal server error",
      message: process.env.NODE_ENV === "development" ? error.message : undefined,
      details: process.env.NODE_ENV === "development" ? error.stack : undefined
    });
  }
});

/**
 * POST /api/auth/login
 * Meldet einen Benutzer an
 */
router.post("/login", async (req: Request, res: Response) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: "Email and password are required" });
    }

    // Benutzer finden
    const user = await prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      return res.status(401).json({ error: "Invalid email or password" });
    }

    // Passwort verifizieren
    const isValid = await verifyPassword(user.passwordHash, password);

    if (!isValid) {
      return res.status(401).json({ error: "Invalid email or password" });
    }

    // JWT-Token generieren
    const token = generateToken({
      userId: user.id,
      email: user.email,
    });

    res.json({
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        createdAt: user.createdAt,
      },
      token,
    });
  } catch (error: any) {
    console.error("Login error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * GET /api/auth/me
 * Liefert Informationen zum aktuellen Benutzer
 */
router.get("/me", authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        email: true,
        createdAt: true,
      },
    });

    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }

    res.json({ user });
  } catch (error: any) {
    console.error("Get user error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * POST /api/auth/logout
 * Logout (optional, da JWT stateless ist)
 */
router.post("/logout", authenticateToken, async (req: Request, res: Response) => {
  // Da JWT stateless ist, gibt es hier nichts zu tun
  // In einer produktiven App könnte man hier eine Token-Blacklist implementieren
  res.json({ message: "Logged out successfully" });
});

export default router;

