import express from "express";
import multer from "multer";
import { PrismaClient } from "@prisma/client";
import { authenticateToken, AuthRequest } from "../middleware/auth";
import { generateCardsFromPDF } from "../services/pdfService";
import { generateCardsFromText } from "../services/openaiService";
import { initializeCardState } from "../fsrs/fsrs";

const router = express.Router();
const prisma = new PrismaClient();

// Configure multer for file uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype === "application/pdf") {
      cb(null, true);
    } else {
      cb(new Error("Only PDF files are allowed"));
    }
  },
});

/**
 * POST /api/import/pdf
 * Import flashcards from PDF
 */
router.post(
  "/pdf",
  authenticateToken,
  upload.single("file"),
  async (req: AuthRequest, res) => {
    try {
      const { boxId, sourceLanguage, targetLanguage, maxCards } = req.body;
      const file = req.file;

      if (!boxId) {
        return res.status(400).json({ error: "boxId is required" });
      }

      if (!file) {
        return res.status(400).json({ error: "PDF file is required" });
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

      // Check OpenAI API key
      if (!process.env.OPENAI_API_KEY) {
        return res.status(500).json({
          error: "OpenAI API key not configured on server",
        });
      }

      // Generate cards from PDF
      const generatedCards = await generateCardsFromPDF(file.buffer, {
        sourceLanguage,
        targetLanguage,
        maxCards: maxCards ? parseInt(maxCards) : undefined,
      });

      // Initialize FSRS state for all cards
      const initialState = initializeCardState();

      // Save cards to database
      const savedCards = await Promise.all(
        generatedCards.map((card) =>
          prisma.card.create({
            data: {
              boxId,
              front: card.front,
              back: card.back,
              tags: card.tags || null,
              stability: initialState.stability,
              difficulty: initialState.difficulty,
              reps: initialState.reps,
              lapses: initialState.lapses,
              due: initialState.due,
            },
          })
        )
      );

      res.status(201).json({
        message: `Successfully imported ${savedCards.length} cards`,
        cards: savedCards,
      });
    } catch (error: any) {
      console.error("PDF import error:", error);
      res.status(500).json({
        error: error.message || "Failed to import PDF",
      });
    }
  }
);

/**
 * POST /api/import/text
 * Import flashcards from text
 */
router.post("/text", authenticateToken, async (req: AuthRequest, res) => {
  try {
    const { boxId, text, sourceLanguage, targetLanguage, maxCards } = req.body;

    if (!boxId || !text) {
      return res.status(400).json({
        error: "boxId and text are required",
      });
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

    // Check OpenAI API key
    if (!process.env.OPENAI_API_KEY) {
      return res.status(500).json({
        error: "OpenAI API key not configured on server",
      });
    }

    // Generate cards from text
    const generatedCards = await generateCardsFromText(text, {
      sourceLanguage,
      targetLanguage,
      maxCards: maxCards ? parseInt(maxCards) : undefined,
    });

    // Initialize FSRS state for all cards
    const initialState = initializeCardState();

    // Save cards to database
    const savedCards = await Promise.all(
      generatedCards.map((card) =>
        prisma.card.create({
          data: {
            boxId,
            front: card.front,
            back: card.back,
            tags: card.tags || null,
            stability: initialState.stability,
            difficulty: initialState.difficulty,
            reps: initialState.reps,
            lapses: initialState.lapses,
            due: initialState.due,
          },
        })
      )
    );

    res.status(201).json({
      message: `Successfully imported ${savedCards.length} cards`,
      cards: savedCards,
    });
  } catch (error: any) {
    console.error("Text import error:", error);
    res.status(500).json({
      error: error.message || "Failed to import text",
    });
  }
});

export default router;

