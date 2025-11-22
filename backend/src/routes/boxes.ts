import { Router, Request, Response } from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken } from "../middleware/auth";
import { authenticateTokenOrApiKey } from "../middleware/authOptional";

const router = Router();
const prisma = new PrismaClient();

/**
 * GET /api/boxes
 * Liefert alle Boxen des aktuellen Benutzers
 */
router.get("/", authenticateTokenOrApiKey, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;

    const boxes = await prisma.box.findMany({
      where: { userId },
      orderBy: { createdAt: "desc" },
      include: {
        _count: {
          select: { cards: true },
        },
      },
    });

    res.json({ boxes });
  } catch (error: any) {
    console.error("Get boxes error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * POST /api/boxes
 * Erstellt eine neue Box
 */
router.post("/", authenticateTokenOrApiKey, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { name } = req.body;

    if (!name || name.trim().length === 0) {
      return res.status(400).json({ error: "Box name is required" });
    }

    const box = await prisma.box.create({
      data: {
        name: name.trim(),
        userId,
      },
    });

    res.status(201).json({ box });
  } catch (error: any) {
    console.error("Create box error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * PUT /api/boxes/:boxId
 * Aktualisiert eine Box (z.B. Name ändern)
 */
router.put("/:boxId", authenticateTokenOrApiKey, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { boxId } = req.params;
    const { name } = req.body;

    if (!name || name.trim().length === 0) {
      return res.status(400).json({ error: "Box name is required" });
    }

    // Prüfe, ob Box existiert und dem Benutzer gehört
    const box = await prisma.box.findFirst({
      where: {
        id: boxId,
        userId,
      },
    });

    if (!box) {
      return res.status(404).json({ error: "Box not found" });
    }

    const updatedBox = await prisma.box.update({
      where: { id: boxId },
      data: { name: name.trim() },
    });

    res.json({ box: updatedBox });
  } catch (error: any) {
    console.error("Update box error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * DELETE /api/boxes/:boxId
 * Löscht eine Box (inkl. aller Karten und ReviewLogs)
 */
router.delete("/:boxId", authenticateTokenOrApiKey, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { boxId } = req.params;

    // Prüfe, ob Box existiert und dem Benutzer gehört
    const box = await prisma.box.findFirst({
      where: {
        id: boxId,
        userId,
      },
    });

    if (!box) {
      return res.status(404).json({ error: "Box not found" });
    }

    // Box löschen (Cascade löscht automatisch Cards und ReviewLogs)
    await prisma.box.delete({
      where: { id: boxId },
    });

    res.json({ message: "Box deleted successfully" });
  } catch (error: any) {
    console.error("Delete box error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

export default router;

