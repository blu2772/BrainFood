import express from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken, AuthRequest } from "../middleware/auth";
import { scheduleNextReview, ReviewRating } from "../fsrs/fsrs";

const router = express.Router();
const prisma = new PrismaClient();

/**
 * GET /api/boxes/:boxId/reviews/next
 * Get the next due card(s) for review
 */
router.get("/boxes/:boxId/reviews/next", authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { boxId } = req.params;
    const limit = parseInt(req.query.limit as string) || 1;

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

    const now = new Date();

    // Get due cards, sorted by oldest due date first
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

    res.json({ cards });
  } catch (error) {
    console.error("Get next reviews error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * POST /api/cards/:cardId/review
 * Submit a review rating for a card
 */
router.post("/cards/:cardId/review", authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { cardId } = req.params;
    const { rating } = req.body;

    if (!rating || !["again", "hard", "good", "easy"].includes(rating)) {
      return res.status(400).json({
        error: "Rating must be one of: again, hard, good, easy",
      });
    }

    // Get card and verify ownership
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

    // Get current card state
    const currentState = {
      stability: card.stability,
      difficulty: card.difficulty,
      reps: card.reps,
      lapses: card.lapses,
      lastReviewAt: card.lastReviewAt,
      due: card.due,
    };

    // Calculate new state using FSRS-5
    const now = new Date();
    const result = scheduleNextReview(
      currentState,
      rating as ReviewRating,
      now
    );

    // Save previous state for review log
    const previousStability = card.stability;
    const previousDue = card.due;

    // Update card with new state
    const updatedCard = await prisma.card.update({
      where: { id: cardId },
      data: {
        stability: result.newState.stability,
        difficulty: result.newState.difficulty,
        reps: result.newState.reps,
        lapses: result.newState.lapses,
        lastReviewAt: result.newState.lastReviewAt,
        due: result.newState.due,
      },
    });

    // Create review log entry
    await prisma.reviewLog.create({
      data: {
        cardId,
        userId: req.userId!,
        rating,
        previousStability,
        newStability: result.newState.stability,
        previousDue,
        newDue: result.newState.due,
        interval: result.interval,
      },
    });

    res.json({
      card: updatedCard,
      nextDue: result.newState.due,
      interval: result.interval,
    });
  } catch (error) {
    console.error("Review card error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

export default router;

