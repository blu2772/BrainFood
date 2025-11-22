import express from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken, AuthRequest } from "../middleware/auth";

const router = express.Router();
const prisma = new PrismaClient();

/**
 * GET /api/boxes/:boxId/stats
 * Get statistics for a box
 */
router.get("/boxes/:boxId/stats", authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { boxId } = req.params;

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

    // Count due cards
    const dueCount = await prisma.card.count({
      where: {
        boxId,
        due: {
          lte: now,
        },
      },
    });

    // Get next due date
    const nextDueCard = await prisma.card.findFirst({
      where: {
        boxId,
        due: {
          gt: now,
        },
      },
      orderBy: {
        due: "asc",
      },
      select: {
        due: true,
      },
    });

    // Total cards
    const totalCards = await prisma.card.count({
      where: { boxId },
    });

    // Total reviews (from review logs)
    const totalReviews = await prisma.reviewLog.count({
      where: {
        card: {
          boxId,
        },
      },
    });

    // Total lapses
    const totalLapses = await prisma.reviewLog.count({
      where: {
        card: {
          boxId,
        },
        rating: "again",
      },
    });

    // Recent reviews (last 7 days)
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const recentReviews = await prisma.reviewLog.count({
      where: {
        card: {
          boxId,
        },
        reviewedAt: {
          gte: sevenDaysAgo,
        },
      },
    });

    res.json({
      dueCount,
      nextDue: nextDueCard?.due || null,
      totalCards,
      totalReviews,
      totalLapses,
      recentReviews,
    });
  } catch (error) {
    console.error("Get stats error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

export default router;

