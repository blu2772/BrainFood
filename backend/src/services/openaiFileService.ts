import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export interface StreamEvent {
  type: "status" | "content" | "error" | "done";
  message: string;
  data?: any;
}

/**
 * Generiert Karteikarten aus einer Datei (PDF oder Bild) mit OpenAI Vision API
 * Sendet Live-Updates während der Generierung
 * WICHTIG: OpenAI Vision API unterstützt nur Bilder, keine PDFs!
 * Für PDFs wird der Text extrahiert und dann der Text-Stream verwendet.
 */
export async function* generateCardsFromFileStream(
  fileBuffer: Buffer,
  filename: string,
  mimeType: string,
  goal: string | undefined,
  sourceLanguage: string = "Deutsch",
  targetLanguage: string = "Englisch",
  onStatusUpdate?: (status: string) => void
): AsyncGenerator<StreamEvent, void, unknown> {
  if (!process.env.OPENAI_API_KEY) {
    yield { type: "error", message: "OPENAI_API_KEY is not set" };
    return;
  }

  try {
    // WICHTIG: OpenAI Vision API unterstützt nur Bilder, keine PDFs!
    if (mimeType === "application/pdf") {
      yield { type: "error", message: "PDFs müssen zuerst zu Text konvertiert werden. Bitte verwende die Text-Import-Funktion." };
      return;
    }

    if (!mimeType.startsWith("image/")) {
      yield { type: "error", message: "Nur Bilder werden unterstützt. PDFs müssen zuerst zu Text konvertiert werden." };
      return;
    }

    yield { type: "status", message: "Bereite Bild für OpenAI vor..." };
    onStatusUpdate?.("Bereite Bild vor...");

    // Konvertiere Bild zu Base64 für direkten Upload
    const base64File = fileBuffer.toString("base64");
    const fileDataUrl = `data:${mimeType};base64,${base64File}`;

    yield { type: "status", message: "✓ Bild vorbereitet" };
    onStatusUpdate?.("✓ Bild vorbereitet");

    // Erstelle Prompt
    const prompt = goal
      ? `Ziel: ${goal}\n\nAnalysiere den Inhalt dieses Bildes und erstelle Vokabelkarten im Format:
- Front: Das zu lernende Wort/Phrase in ${sourceLanguage}
- Back: Die Übersetzung/Erklärung in ${targetLanguage}
- Tags: Relevante Themen/Kategorien (optional, kommagetrennt)

Antworte NUR mit einem JSON-Array im folgenden Format:
[
  {
    "front": "Wort in ${sourceLanguage}",
    "back": "Übersetzung in ${targetLanguage}",
    "tags": "tag1, tag2"
  }
]

Erstelle so viele Karten wie sinnvoll möglich.`
      : `Analysiere den Inhalt dieses Bildes und erstelle Vokabelkarten im Format:
- Front: Das zu lernende Wort/Phrase in ${sourceLanguage}
- Back: Die Übersetzung/Erklärung in ${targetLanguage}
- Tags: Relevante Themen/Kategorien (optional, kommagetrennt)

Antworte NUR mit einem JSON-Array im folgenden Format:
[
  {
    "front": "Wort in ${sourceLanguage}",
    "back": "Übersetzung in ${targetLanguage}",
    "tags": "tag1, tag2"
  }
]

Erstelle so viele Karten wie sinnvoll möglich.`;

    yield { type: "status", message: "KI analysiert Bild..." };
    onStatusUpdate?.("KI analysiert Bild...");

    // Verwende Vision API nur für Bilder
    const completion = await openai.chat.completions.create({
      model: "gpt-4o", // Vision-fähiges Modell
      messages: [
        {
          role: "system",
          content: "Du bist ein Experte für das Erstellen von Lernkarten. Antworte immer nur mit gültigem JSON.",
        },
        {
          role: "user",
          content: [
            { type: "text", text: prompt },
            {
              type: "image_url",
              image_url: {
                url: fileDataUrl, // Bild als Base64 Data URL
              },
            },
          ],
        },
      ],
      temperature: 0.7,
      stream: true,
    });

    yield { type: "status", message: "KI generiert Karten aus Bild..." };
    onStatusUpdate?.("KI generiert Karten...");

    let fullContent = "";
    let buffer = "";

    for await (const chunk of completion) {
      const content = chunk.choices[0]?.delta?.content || "";

      if (content) {
        fullContent += content;
        buffer += content;

        if (buffer.length > 50) {
          yield {
            type: "content",
            message: "KI schreibt...",
            data: { partial: buffer.substring(0, 100) },
          };
          buffer = "";
        }
      }

      // Prüfe auf Finish Reason
      if (chunk.choices[0]?.finish_reason) {
        if (chunk.choices[0].finish_reason === "stop") {
          yield { type: "status", message: "KI hat Antwort abgeschlossen..." };
          onStatusUpdate?.("KI hat Antwort abgeschlossen...");
        } else if (chunk.choices[0].finish_reason === "length") {
          yield { type: "status", message: "⚠ Antwort wurde abgeschnitten (zu lang)" };
          onStatusUpdate?.("⚠ Antwort wurde abgeschnitten");
        }
      }
    }

    // Parse JSON
    yield { type: "status", message: "Parse JSON-Antwort..." };
    onStatusUpdate?.("Parse JSON-Antwort...");

    let parsed: any;
    try {
      parsed = JSON.parse(fullContent);
    } catch (e: any) {
      yield {
        type: "error",
        message: `JSON Parse Fehler: ${e.message}`,
        data: { rawContent: fullContent.substring(0, 500) },
      };
      return;
    }

    // Normalisiere das Format und validiere Karten
    let rawCards: any[] = [];
    if (Array.isArray(parsed)) {
      rawCards = parsed;
    } else if (parsed.cards && Array.isArray(parsed.cards)) {
      rawCards = parsed.cards;
    } else if (parsed.data && Array.isArray(parsed.data)) {
      rawCards = parsed.data;
    } else {
      // Wenn das Format nicht erkannt wird, versuche es als einzelne Karte zu behandeln
      if (parsed && typeof parsed === "object" && parsed.front && parsed.back) {
        rawCards = [parsed];
      } else {
        yield {
          type: "error",
          message: "Ungültiges Format: Die KI hat keine Karten zurückgegeben",
          data: { rawContent: fullContent.substring(0, 500) },
        };
        return;
      }
    }

    // Validiere und filtere ungültige Karten
    const validCards = rawCards
      .map((card: any) => {
        // Stelle sicher, dass front und back Strings sind
        const front = typeof card.front === "string" ? card.front.trim() : String(card.front || "").trim();
        const back = typeof card.back === "string" ? card.back.trim() : String(card.back || "").trim();
        const tags = typeof card.tags === "string" ? card.tags.trim() : (card.tags ? String(card.tags).trim() : "");

        // Prüfe ob front und back nicht leer sind
        if (!front || !back) {
          return null;
        }

        return {
          front,
          back,
          tags,
        };
      })
      .filter((card): card is { front: string; back: string; tags: string } => card !== null);

    if (validCards.length === 0) {
      yield {
        type: "error",
        message: "Keine gültigen Karten gefunden. Bitte versuche es erneut.",
        data: { rawContent: fullContent.substring(0, 500) },
      };
      return;
    }

    yield {
      type: "status",
      message: `✓ ${validCards.length} Karte${validCards.length === 1 ? "" : "n"} erfolgreich erstellt`,
    };
    onStatusUpdate?.(`✓ ${validCards.length} Karten erstellt`);

    yield {
      type: "done",
      message: "Fertig",
      data: {
        cards: validCards,
      },
    };
  } catch (error: any) {
    console.error("OpenAI File Streaming Error:", error);

    let errorMessage = "Unbekannter Fehler";
    if (error.message) {
      errorMessage = error.message;
    } else if (error.error?.message) {
      errorMessage = error.error.message;
    } else if (typeof error === "string") {
      errorMessage = error;
    }

    yield {
      type: "error",
      message: `OpenAI Fehler: ${errorMessage}`,
      data: { error: error },
    };
  }
}
