import express from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken, AuthRequest } from "../middleware/auth";
import { initializeCardState } from "../fsrs/fsrs";

const router = express.Router();
const prisma = new PrismaClient();

/**
 * GET /api/boxes/:boxId/cards
 * Get all cards in a box
 */
router.get("/boxes/:boxId/cards", authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { boxId } = req.params;
    const { search, sort } = req.query;

    // Verify box ownership
    const box = await prisma.box.findFirst({
      where: {
        id: boxId,
        userId: req.userId!,
      },
    });

    if (!box) {
      return res.status(404).json({ error: "Box not found" });
    }

    // Build where clause
    const where: any = { boxId };

    if (search && typeof search === "string") {
      where.OR = [
        { front: { contains: search, mode: "insensitive" } },
        { back: { contains: search, mode: "insensitive" } },
      ];
    }

    // Build orderBy
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
  } catch (error) {
    console.error("Get cards error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * POST /api/boxes/:boxId/cards
 * Create a new card
 */
router.post("/boxes/:boxId/cards", authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { boxId } = req.params;
    const { front, back, tags } = req.body;

    if (!front || !back) {
      return res.status(400).json({ error: "Front and back are required" });
    }

    // Verify box ownership
    const box = await prisma.box.findFirst({
      where: {
        id: boxId,
        userId: req.userId!,
      },
    });

    if (!box) {
      return res.status(404).json({ error: "Box not found" });
    }

    // Initialize FSRS state
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
  } catch (error) {
    console.error("Create card error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * GET /api/cards/:cardId
 * Get a single card
 */
router.get("/:cardId", authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { cardId } = req.params;

    const card = await prisma.card.findFirst({
      where: {
        id: cardId,
        box: {
          userId: req.userId!,
        },
      },
    });

    if (!card) {
      return res.status(404).json({ error: "Card not found" });
    }

    res.json({ card });
  } catch (error) {
    console.error("Get card error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * PUT /api/cards/:cardId
 * Update a card
 */
router.put("/:cardId", authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { cardId } = req.params;
    const { front, back, tags } = req.body;

    // Verify ownership
    const existingCard = await prisma.card.findFirst({
      where: {
        id: cardId,
        box: {
          userId: req.userId!,
        },
      },
    });

    if (!existingCard) {
      return res.status(404).json({ error: "Card not found" });
    }

    const updateData: any = {};
    if (front !== undefined) updateData.front = front.trim();
    if (back !== undefined) updateData.back = back.trim();
    if (tags !== undefined) updateData.tags = tags ? tags.trim() : null;

    const card = await prisma.card.update({
      where: { id: cardId },
      data: updateData,
    });

    res.json({ card });
  } catch (error) {
    console.error("Update card error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * DELETE /api/cards/:cardId
 * Delete a card
 */
router.delete("/:cardId", authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { cardId } = req.params;

    // Verify ownership
    const existingCard = await prisma.card.findFirst({
      where: {
        id: cardId,
        box: {
          userId: req.userId!,
        },
      },
    });

    if (!existingCard) {
      return res.status(404).json({ error: "Card not found" });
    }

    await prisma.card.delete({
      where: { id: cardId },
    });

    res.json({ message: "Card deleted successfully" });
  } catch (error) {
    console.error("Delete card error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

export default router;

