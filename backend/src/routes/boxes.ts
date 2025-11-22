import express from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken, AuthRequest } from "../middleware/auth";

const router = express.Router();
const prisma = new PrismaClient();

/**
 * GET /api/boxes
 * Get all boxes for the current user
 */
router.get("/", authenticateToken, async (req: AuthRequest, res) => {
  try {
    const boxes = await prisma.box.findMany({
      where: { userId: req.userId! },
      orderBy: { createdAt: "desc" },
      include: {
        _count: {
          select: { cards: true },
        },
      },
    });

    res.json({ boxes });
  } catch (error) {
    console.error("Get boxes error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * POST /api/boxes
 * Create a new box
 */
router.post("/", authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { name } = req.body;

    if (!name || name.trim().length === 0) {
      return res.status(400).json({ error: "Box name is required" });
    }

    const box = await prisma.box.create({
      data: {
        name: name.trim(),
        userId: req.userId!,
      },
      include: {
        _count: {
          select: { cards: true },
        },
      },
    });

    res.status(201).json({ box });
  } catch (error) {
    console.error("Create box error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * PUT /api/boxes/:boxId
 * Update a box
 */
router.put("/:boxId", authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { boxId } = req.params;
    const { name } = req.body;

    if (!name || name.trim().length === 0) {
      return res.status(400).json({ error: "Box name is required" });
    }

    // Verify ownership
    const existingBox = await prisma.box.findFirst({
      where: {
        id: boxId,
        userId: req.userId!,
      },
    });

    if (!existingBox) {
      return res.status(404).json({ error: "Box not found" });
    }

    const box = await prisma.box.update({
      where: { id: boxId },
      data: { name: name.trim() },
      include: {
        _count: {
          select: { cards: true },
        },
      },
    });

    res.json({ box });
  } catch (error) {
    console.error("Update box error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

/**
 * DELETE /api/boxes/:boxId
 * Delete a box (cascades to cards and review logs)
 */
router.delete("/:boxId", authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { boxId } = req.params;

    // Verify ownership
    const existingBox = await prisma.box.findFirst({
      where: {
        id: boxId,
        userId: req.userId!,
      },
    });

    if (!existingBox) {
      return res.status(404).json({ error: "Box not found" });
    }

    await prisma.box.delete({
      where: { id: boxId },
    });

    res.json({ message: "Box deleted successfully" });
  } catch (error) {
    console.error("Delete box error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

export default router;

