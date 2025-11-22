import { Router, Request, Response } from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken } from "../middleware/auth";
import { authenticateTokenOrApiKey } from "../middleware/authOptional";
import { initializeCardState } from "../fsrs/fsrs";

const router = Router();
const prisma = new PrismaClient();

/**
 * GET /api/boxes/:boxId/cards
 * Liefert alle Karten einer Box
 */
router.get("/boxes/:boxId/cards", authenticateTokenOrApiKey, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { boxId } = req.params;
    const { search, sort } = req.query;

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

    // Filter und Sortierung
    const where: any = { boxId };
    if (search && typeof search === "string") {
      where.OR = [
        { front: { contains: search, mode: "insensitive" } },
        { back: { contains: search, mode: "insensitive" } },
      ];
    }

    const orderBy: any = {};
    if (sort === "due") {
      orderBy.due = "asc";
    } else {
      orderBy.createdAt = "desc";
    }

    const cards = await prisma.card.findMany({
      where,
      orderBy,
    });

    res.json({ cards });
  } catch (error: any) {
    console.error("Get cards error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * POST /api/boxes/:boxId/cards
 * Erstellt eine neue Karte
 */
router.post("/boxes/:boxId/cards", authenticateTokenOrApiKey, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { boxId } = req.params;
    const { front, back, tags } = req.body;

    if (!front || !back) {
      return res.status(400).json({ error: "Front and back are required" });
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

    // Initialisiere FSRS-State
    const initialState = initializeCardState();

    const card = await prisma.card.create({
      data: {
        boxId,
        front: front.trim(),
        back: back.trim(),
        tags: tags ? tags.trim() : null,
        stability: initialState.stability,
        difficulty: initialState.difficulty,
        reps: initialState.reps,
        lapses: initialState.lapses,
        due: initialState.due,
      },
    });

    res.status(201).json({ card });
  } catch (error: any) {
    console.error("Create card error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * GET /api/cards/:cardId
 * Liefert Details einer Karte
 */
router.get("/:cardId", authenticateTokenOrApiKey, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { cardId } = req.params;

    const card = await prisma.card.findFirst({
      where: {
        id: cardId,
        box: {
          userId,
        },
      },
    });

    if (!card) {
      return res.status(404).json({ error: "Card not found" });
    }

    res.json({ card });
  } catch (error: any) {
    console.error("Get card error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * PUT /api/cards/:cardId
 * Aktualisiert eine Karte
 */
router.put("/:cardId", authenticateTokenOrApiKey, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { cardId } = req.params;
    const { front, back, tags } = req.body;

    // Prüfe, ob Karte existiert und dem Benutzer gehört
    const card = await prisma.card.findFirst({
      where: {
        id: cardId,
        box: {
          userId,
        },
      },
    });

    if (!card) {
      return res.status(404).json({ error: "Card not found" });
    }

    const updateData: any = {};
    if (front !== undefined) updateData.front = front.trim();
    if (back !== undefined) updateData.back = back.trim();
    if (tags !== undefined) updateData.tags = tags ? tags.trim() : null;

    const updatedCard = await prisma.card.update({
      where: { id: cardId },
      data: updateData,
    });

    res.json({ card: updatedCard });
  } catch (error: any) {
    console.error("Update card error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * DELETE /api/cards/:cardId
 * Löscht eine Karte
 */
router.delete("/:cardId", authenticateTokenOrApiKey, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { cardId } = req.params;

    // Prüfe, ob Karte existiert und dem Benutzer gehört
    const card = await prisma.card.findFirst({
      where: {
        id: cardId,
        box: {
          userId,
        },
      },
    });

    if (!card) {
      return res.status(404).json({ error: "Card not found" });
    }

    await prisma.card.delete({
      where: { id: cardId },
    });

    res.json({ message: "Card deleted successfully" });
  } catch (error: any) {
    console.error("Delete card error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

export default router;

