import { Router, Request, Response } from "express";
import multer from "multer";
import { PrismaClient } from "@prisma/client";
import { authenticateTokenOrApiKey } from "../middleware/authOptional";
import { generateCardsFromFileStream } from "../services/openaiFileService";
import { generateCardsFromTextStream } from "../services/openaiStreamService";
import { extractTextFromPDF, chunkText } from "../services/pdfService";

const router = Router();
const prisma = new PrismaClient();

// Multer-Konfiguration für PDF und Bild-Upload
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 20 * 1024 * 1024, // 20 MB (erhöht für größere PDFs/Bilder)
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype === "application/pdf" || file.mimetype.startsWith("image/")) {
      cb(null, true);
    } else {
      cb(new Error("Only PDF files and images are allowed"));
    }
  },
});

/**
 * POST /api/import/suggest-stream
 * Generiert Karten-Vorschläge mit Live-Streaming (Server-Sent Events)
 */
router.post(
  "/suggest-stream",
  authenticateTokenOrApiKey,
  upload.single("file"),
  async (req: Request, res: Response) => {
    try {
      const userId = (req as any).userId;
      const { boxId, text, goal, sourceLanguage, targetLanguage, desiredCardCount } = req.body;

      if (!boxId) {
        return res.status(400).json({ error: "boxId is required" });
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

      // Setze SSE Headers
      res.setHeader("Content-Type", "text/event-stream");
      res.setHeader("Cache-Control", "no-cache");
      res.setHeader("Connection", "keep-alive");
      res.setHeader("X-Accel-Buffering", "no"); // Disable nginx buffering

      const sendEvent = (event: { type: string; message: string; data?: any }) => {
        res.write(`data: ${JSON.stringify(event)}\n\n`);
      };

      const allCards: Array<{ front: string; back: string; tags?: string }> = [];

      // Wenn Datei hochgeladen wurde
      if (req.file) {
        const mimetype = req.file.mimetype;
        const filename = req.file.originalname || (mimetype.startsWith("image/") ? "image.jpg" : "document.pdf");

        try {
          let fileCards: Array<{ front: string; back: string; tags?: string }> = [];

          // WICHTIG: OpenAI Vision API unterstützt nur Bilder, keine PDFs!
          // Für PDFs: Text extrahieren und dann Text-Stream verwenden
          if (mimetype === "application/pdf") {
            sendEvent({ type: "status", message: "Extrahiere Text aus PDF..." });
            
            const pdfText = await extractTextFromPDF(req.file.buffer);
            
            if (!pdfText || pdfText.trim().length === 0) {
              sendEvent({ 
                type: "error", 
                message: "Konnte keinen Text aus PDF extrahieren" 
              });
            } else {
              sendEvent({ type: "status", message: `✓ ${pdfText.length} Zeichen extrahiert` });
              
              // Teile Text in Chunks
              const chunks = chunkText(pdfText, 3000);
              sendEvent({ type: "status", message: `Verarbeite ${chunks.length} Abschnitte...` });

              // Verarbeite jeden Chunk
              for (let i = 0; i < chunks.length; i++) {
                const chunk = chunks[i];
                sendEvent({ type: "status", message: `Verarbeite Abschnitt ${i + 1} von ${chunks.length}...` });

                const desiredCount = desiredCardCount ? parseInt(desiredCardCount, 10) : undefined;
                for await (const event of generateCardsFromTextStream(
                  chunk,
                  sourceLanguage || "Deutsch",
                  targetLanguage || "Englisch",
                  goal || undefined,
                  desiredCount,
                  (status) => {
                    sendEvent({ type: "status", message: status });
                  }
                )) {
                  sendEvent(event);
                  if (event.type === "done" && event.data?.cards) {
                    fileCards.push(...event.data.cards);
                  } else if (event.type === "error") {
                    sendEvent({ 
                      type: "error", 
                      message: `Fehler in Abschnitt ${i + 1}: ${event.message}` 
                    });
                  }
                }
              }
            }
          } else if (mimetype.startsWith("image/")) {
            // Für Bilder: Direkt an OpenAI Vision API senden
            const desiredCount = desiredCardCount ? parseInt(desiredCardCount, 10) : undefined;
            for await (const event of generateCardsFromFileStream(
              req.file.buffer,
              filename,
              mimetype,
              goal || undefined,
              sourceLanguage || "Deutsch",
              targetLanguage || "Englisch",
              desiredCount,
              (status) => {
                sendEvent({ type: "status", message: status });
              }
            )) {
              // Sende alle Events weiter
              sendEvent(event);

              if (event.type === "done" && event.data?.cards) {
                fileCards = event.data.cards;
              } else if (event.type === "error") {
                sendEvent({ 
                  type: "error", 
                  message: event.message 
                });
              }
            }
          } else {
            sendEvent({ 
              type: "error", 
              message: "Nur PDFs und Bilder werden unterstützt" 
            });
          }

          if (fileCards.length > 0) {
            allCards.push(...fileCards);
          }
        } catch (error: any) {
          console.error("Error processing file:", error);
          sendEvent({ 
            type: "error", 
            message: `Fehler beim Verarbeiten der Datei: ${error.message}` 
          });
        }
      } else if (text) {
        // Fallback: Text direkt verarbeiten
        sendEvent({ type: "status", message: "Verarbeite Text..." });

        // Erstelle Prompt mit Ziel
        const prompt = goal 
          ? `Ziel: ${goal}\n\nInhalt:\n${text}`
          : text;

        // Teile Text in Chunks
        sendEvent({ type: "status", message: "Teile Text in Abschnitte..." });
        const chunks = chunkText(prompt, 3000);
        sendEvent({ type: "status", message: `✓ ${chunks.length} Abschnitte erstellt` });

        // Generiere Karten aus jedem Chunk mit Streaming
        for (let i = 0; i < chunks.length; i++) {
          const chunk = chunks[i];
          sendEvent({ 
            type: "status", 
            message: `Verarbeite Abschnitt ${i + 1} von ${chunks.length}...` 
          });

          try {
            let chunkCards: Array<{ front: string; back: string; tags?: string }> = [];
            let hasError = false;
            
            const desiredCount = desiredCardCount ? parseInt(desiredCardCount, 10) : undefined;
            for await (const event of generateCardsFromTextStream(
              chunk,
              sourceLanguage || "Deutsch",
              targetLanguage || "Englisch",
              goal || undefined,
              desiredCount,
              (status) => {
                sendEvent({ type: "status", message: status });
              }
            )) {
              sendEvent(event);

              if (event.type === "done" && event.data?.cards) {
                chunkCards = event.data.cards;
              } else if (event.type === "error") {
                hasError = true;
                sendEvent({ 
                  type: "status", 
                  message: `⚠ Fehler in Abschnitt ${i + 1}: ${event.message}` 
                });
              }
            }

            if (!hasError && chunkCards.length > 0) {
              allCards.push(...chunkCards);
              sendEvent({ 
                type: "status", 
                message: `✓ ${chunkCards.length} Karten aus Abschnitt ${i + 1} erstellt` 
              });
            }
          } catch (error: any) {
            console.error(`Error generating cards from chunk ${i + 1}:`, error);
            sendEvent({ 
              type: "error", 
              message: `Fehler in Abschnitt ${i + 1}: ${error.message}` 
            });
          }
        }
      } else {
        sendEvent({ type: "error", message: "Text content or file is required" });
        res.end();
        return;
      }

      if (allCards.length === 0) {
        sendEvent({ type: "error", message: "No cards could be generated" });
        res.end();
        return;
      }

      // Finale Antwort
      sendEvent({ 
        type: "done", 
        message: `Fertig! ${allCards.length} Karten erstellt`,
        data: { cards: allCards }
      });

      res.end();
    } catch (error: any) {
      console.error("Stream error:", error);
      res.write(`data: ${JSON.stringify({ type: "error", message: error.message })}\n\n`);
      res.end();
    }
  }
);

export default router;

