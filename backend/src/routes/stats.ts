import { Router, Request, Response } from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken } from "../middleware/auth";

const router = Router();
const prisma = new PrismaClient();

/**
 * GET /api/boxes/:boxId/stats
 * Liefert Statistiken für eine Box
 */
router.get("/boxes/:boxId/stats", authenticateToken, async (req: Request, res: Response) => {
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

    const now = new Date();

    // Anzahl fälliger Karten
    const dueCount = await prisma.card.count({
      where: {
        boxId,
        due: {
          lte: now,
        },
      },
    });

    // Nächste Fälligkeit
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
    });

    // Gesamtanzahl Karten
    const totalCards = await prisma.card.count({
      where: { boxId },
    });

    // Anzahl Wiederholungen (Reviews)
    const totalReviews = await prisma.reviewLog.count({
      where: {
        card: {
          boxId,
        },
      },
    });

    // Anzahl Lapses (Fehler)
    const totalLapses = await prisma.card.aggregate({
      where: { boxId },
      _sum: {
        lapses: true,
      },
    });

    // Tägliche Review-Counts der letzten 7 Tage
    const sevenDaysAgo = new Date(now);
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const dailyReviews = await prisma.reviewLog.groupBy({
      by: ["reviewedAt"],
      where: {
        card: {
          boxId,
        },
        reviewedAt: {
          gte: sevenDaysAgo,
        },
      },
      _count: {
        id: true,
      },
    });

    res.json({
      stats: {
        dueCount,
        nextDue: nextDueCard?.due || null,
        totalCards,
        totalReviews,
        totalLapses: totalLapses._sum.lapses || 0,
        dailyReviews: dailyReviews.map((dr) => ({
          date: dr.reviewedAt,
          count: dr._count.id,
        })),
      },
    });
  } catch (error: any) {
    console.error("Get stats error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

export default router;

