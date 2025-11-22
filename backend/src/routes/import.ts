import { Router, Request, Response } from "express";
import multer from "multer";
import { PrismaClient } from "@prisma/client";
import { authenticateToken } from "../middleware/auth";
import { extractTextFromPDF, chunkText } from "../services/pdfService";
import { generateCardsFromText } from "../services/openaiService";
import { initializeCardState } from "../fsrs/fsrs";

const router = Router();
const prisma = new PrismaClient();

// Multer-Konfiguration für PDF-Upload
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10 MB
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
 * Importiert Karten aus einem PDF
 */
router.post(
  "/pdf",
  authenticateToken,
  upload.single("file"),
  async (req: Request, res: Response) => {
    try {
      const userId = (req as any).userId;
      const { boxId, sourceLanguage, targetLanguage } = req.body;

      if (!boxId) {
        return res.status(400).json({ error: "boxId is required" });
      }

      if (!req.file) {
        return res.status(400).json({ error: "PDF file is required" });
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

      // Extrahiere Text aus PDF
      const text = await extractTextFromPDF(req.file.buffer);

      if (!text || text.trim().length === 0) {
        return res.status(400).json({ error: "Could not extract text from PDF" });
      }

      // Teile Text in Chunks
      const chunks = chunkText(text, 3000);

      // Generiere Karten aus jedem Chunk
      const allCards: Array<{ front: string; back: string; tags?: string }> = [];

      for (const chunk of chunks) {
        try {
          const cards = await generateCardsFromText(
            chunk,
            sourceLanguage || "Deutsch",
            targetLanguage || "Englisch"
          );
          allCards.push(...cards);
        } catch (error: any) {
          console.error("Error generating cards from chunk:", error);
          // Weiter mit nächstem Chunk
        }
      }

      if (allCards.length === 0) {
        return res.status(400).json({ error: "No cards could be generated from PDF" });
      }

      // Initialisiere FSRS-State für alle Karten
      const initialState = initializeCardState();

      // Speichere Karten in DB
      const createdCards = await Promise.all(
        allCards.map((cardData) =>
          prisma.card.create({
            data: {
              boxId,
              front: cardData.front,
              back: cardData.back,
              tags: cardData.tags || null,
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
        message: `Successfully imported ${createdCards.length} cards`,
        cards: createdCards,
      });
    } catch (error: any) {
      console.error("PDF import error:", error);
      res.status(500).json({ error: `Import failed: ${error.message}` });
    }
  }
);

/**
 * POST /api/import/text
 * Importiert Karten aus rohem Text
 */
router.post("/text", authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { boxId, text, sourceLanguage, targetLanguage } = req.body;

    if (!boxId || !text) {
      return res.status(400).json({ error: "boxId and text are required" });
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

    // Teile Text in Chunks
    const chunks = chunkText(text, 3000);

    // Generiere Karten aus jedem Chunk
    const allCards: Array<{ front: string; back: string; tags?: string }> = [];

    for (const chunk of chunks) {
      try {
        const cards = await generateCardsFromText(
          chunk,
          sourceLanguage || "Deutsch",
          targetLanguage || "Englisch"
        );
        allCards.push(...cards);
      } catch (error: any) {
        console.error("Error generating cards from chunk:", error);
      }
    }

    if (allCards.length === 0) {
      return res.status(400).json({ error: "No cards could be generated from text" });
    }

    // Initialisiere FSRS-State
    const initialState = initializeCardState();

    // Speichere Karten in DB
    const createdCards = await Promise.all(
      allCards.map((cardData) =>
        prisma.card.create({
          data: {
            boxId,
            front: cardData.front,
            back: cardData.back,
            tags: cardData.tags || null,
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
      message: `Successfully imported ${createdCards.length} cards`,
      cards: createdCards,
    });
  } catch (error: any) {
    console.error("Text import error:", error);
    res.status(500).json({ error: `Import failed: ${error.message}` });
  }
});

export default router;

