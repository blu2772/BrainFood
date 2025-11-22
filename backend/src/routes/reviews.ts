import { Router, Request, Response } from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken } from "../middleware/auth";
import { scheduleNextReview, isCardDue } from "../fsrs/fsrs";

const router = Router();
const prisma = new PrismaClient();

/**
 * GET /api/boxes/:boxId/reviews/next
 * Liefert die nächste(n) fällige(n) Karte(n) für Review
 */
router.get("/boxes/:boxId/reviews/next", authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { boxId } = req.params;
    const limit = parseInt(req.query.limit as string) || 1;

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

    // Finde fällige Karten (due <= now), sortiert nach ältestem due zuerst
    const now = new Date();
    const cards = await prisma.card.findMany({
      where: {
        boxId,
        due: {
          lte: now,
        },
      },
      orderBy: {
        due: "asc",
      },
      take: limit,
    });

    res.json({ cards, count: cards.length });
  } catch (error: any) {
    console.error("Get next reviews error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * POST /api/cards/:cardId/review
 * Verarbeitet eine Review-Bewertung und aktualisiert den FSRS-State
 */
router.post("/cards/:cardId/review", authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { cardId } = req.params;
    const { rating } = req.body;

    if (!rating || !["again", "hard", "good", "easy"].includes(rating)) {
      return res.status(400).json({ 
        error: "Rating is required and must be one of: again, hard, good, easy" 
      });
    }

    // Lade Karte mit Prüfung auf Besitz
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

    // Erstelle CardState aus DB-Daten
    const cardState = {
      stability: card.stability,
      difficulty: card.difficulty,
      reps: card.reps,
      lapses: card.lapses,
      lastReviewAt: card.lastReviewAt,
      due: card.due,
    };

    // Berechne neuen State mit FSRS-5
    const now = new Date();
    const fsrsResult = scheduleNextReview(cardState, rating as any, now);

    // Speichere alten State für ReviewLog
    const previousStability = card.stability;
    const previousDue = card.due;

    // Aktualisiere Karte
    const updatedCard = await prisma.card.update({
      where: { id: cardId },
      data: {
        stability: fsrsResult.newState.stability,
        difficulty: fsrsResult.newState.difficulty,
        reps: fsrsResult.newState.reps,
        lapses: fsrsResult.newState.lapses,
        lastReviewAt: fsrsResult.newState.lastReviewAt,
        due: fsrsResult.newState.due,
      },
    });

    // Erstelle ReviewLog-Eintrag
    await prisma.reviewLog.create({
      data: {
        cardId,
        userId,
        rating,
        previousStability,
        newStability: fsrsResult.newState.stability,
        previousDue,
        newDue: fsrsResult.newState.due,
        interval: fsrsResult.interval,
      },
    });

    res.json({
      card: updatedCard,
      nextDue: fsrsResult.nextDue,
      interval: fsrsResult.interval,
    });
  } catch (error: any) {
    console.error("Review error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

export default router;

