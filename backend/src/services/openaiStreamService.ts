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
 * Generiert Karteikarten aus Text mit OpenAI Streaming
 * Sendet Live-Updates während der Generierung
 */
export async function* generateCardsFromTextStream(
  text: string,
  sourceLanguage: string = "Deutsch",
  targetLanguage: string = "Englisch",
  goal?: string,
  desiredCardCount?: number,
  onStatusUpdate?: (status: string) => void
): AsyncGenerator<StreamEvent, void, unknown> {
  if (!process.env.OPENAI_API_KEY) {
    yield { type: "error", message: "OPENAI_API_KEY is not set" };
    return;
  }

  // Bestimme Kartentyp basierend auf Ziel
  const isVocabularyRequest = goal?.toLowerCase().includes("vokabel") || 
                             goal?.toLowerCase().includes("übersetzung") ||
                             goal?.toLowerCase().includes("wort");
  
  const cardTypeInstruction = isVocabularyRequest
    ? `Erstelle VOKABELKARTEN (Übersetzungen):
- Front: Das zu lernende Wort/Phrase in ${sourceLanguage}
- Back: Die Übersetzung in ${targetLanguage}`
    : `Erstelle LERNKARTEN zu den Themen/Inhalten:
- Front: Eine Frage oder ein Begriff zum Thema
- Back: Die Antwort, Erklärung oder Definition
- Wichtig: Erstelle Frage-Antwort-Paare, die helfen, das Thema zu verstehen und zu lernen`;

  const prompt = goal
    ? `Ziel: ${goal}

Du bist ein Experte für das Erstellen von Lernkarten. ${cardTypeInstruction}
- Tags: Relevante Themen/Kategorien (optional, kommagetrennt)

Text/Inhalt:
${text}

Antworte NUR mit einem JSON-Array im folgenden Format:
[
  {
    "front": "${isVocabularyRequest ? "Wort in " + sourceLanguage : "Frage oder Begriff"}",
    "back": "${isVocabularyRequest ? "Übersetzung in " + targetLanguage : "Antwort oder Erklärung"}",
    "tags": "tag1, tag2"
  }
]

${desiredCardCount && desiredCardCount > 0 ? `Erstelle maximal ${desiredCardCount} Karten. Wenn weniger Inhalt vorhanden ist, erstelle weniger.` : "Erstelle so viele Karten wie sinnvoll möglich."} ${isVocabularyRequest ? "Fokussiere dich auf wichtige Vokabeln und Phrasen." : "Fokussiere dich auf wichtige Konzepte, Definitionen und Zusammenhänge."}`
    : `Du bist ein Experte für das Erstellen von Lernkarten. ${cardTypeInstruction}
- Tags: Relevante Themen/Kategorien (optional, kommagetrennt)

Text/Inhalt:
${text}

Antworte NUR mit einem JSON-Array im folgenden Format:
[
  {
    "front": "${isVocabularyRequest ? "Wort in " + sourceLanguage : "Frage oder Begriff"}",
    "back": "${isVocabularyRequest ? "Übersetzung in " + targetLanguage : "Antwort oder Erklärung"}",
    "tags": "tag1, tag2"
  }
]

${desiredCardCount && desiredCardCount > 0 ? `Erstelle maximal ${desiredCardCount} Karten. Wenn weniger Inhalt vorhanden ist, erstelle weniger.` : "Erstelle so viele Karten wie sinnvoll möglich."} ${isVocabularyRequest ? "Fokussiere dich auf wichtige Vokabeln und Phrasen." : "Fokussiere dich auf wichtige Konzepte, Definitionen und Zusammenhänge."}`;

  try {
    yield { type: "status", message: "Verbinde mit OpenAI..." };
    onStatusUpdate?.("Verbinde mit OpenAI...");

    const stream = await openai.chat.completions.create({
      model: "gpt-5-mini-2025-08-07",
      messages: [
        {
          role: "system",
          content: "Du bist ein Experte für das Erstellen von Lernkarten. Antworte immer nur mit gültigem JSON.",
        },
        {
          role: "user",
          content: prompt,
        },
      ],
      temperature: 0.7,
      stream: true, // Streaming aktivieren
    });

    yield { type: "status", message: "KI generiert Karten..." };
    onStatusUpdate?.("KI generiert Karten...");

    let fullContent = "";
    let buffer = "";
    let partialCards: Array<{ front: string; back: string; tags?: string }> = [];
    let lastParsedIndex = 0;

    // Hilfsfunktion zum Extrahieren von JSON-Objekten aus einem String
    const tryParsePartialJSON = (content: string): Array<{ front: string; back: string; tags?: string }> => {
      const cards: Array<{ front: string; back: string; tags?: string }> = [];
      
      // Entferne Markdown-Code-Blöcke falls vorhanden
      let jsonContent = content.trim();
      if (jsonContent.startsWith("```json")) {
        jsonContent = jsonContent.substring(7).trim();
      } else if (jsonContent.startsWith("```")) {
        jsonContent = jsonContent.substring(3).trim();
      }
      
      // Versuche, vollständige JSON-Objekte zu finden
      let depth = 0;
      let inString = false;
      let escapeNext = false;
      let currentObj = "";
      let braceCount = 0;
      
      for (let i = 0; i < jsonContent.length; i++) {
        const char = jsonContent[i];
        
        if (escapeNext) {
          escapeNext = false;
          currentObj += char;
          continue;
        }
        
        if (char === '\\') {
          escapeNext = true;
          currentObj += char;
          continue;
        }
        
        if (char === '"' && !escapeNext) {
          inString = !inString;
        }
        
        if (!inString) {
          if (char === '[') {
            depth++;
          } else if (char === ']') {
            depth--;
            if (depth === 0 && currentObj.trim()) {
              // Versuche, das Array zu parsen
              try {
                const parsed = JSON.parse("[" + currentObj + "]");
                if (Array.isArray(parsed)) {
                  cards.push(...parsed.filter((c: any) => c && c.front && c.back));
                }
              } catch (e) {
                // Ignoriere Parse-Fehler bei unvollständigem JSON
              }
              currentObj = "";
            }
          } else if (char === '{') {
            if (depth === 1) {
              currentObj = "";
            }
            braceCount++;
            currentObj += char;
          } else if (char === '}') {
            braceCount--;
            currentObj += char;
            if (depth === 1 && braceCount === 0) {
              // Versuche, das Objekt zu parsen
              try {
                const parsed = JSON.parse(currentObj);
                if (parsed && parsed.front && parsed.back) {
                  cards.push(parsed);
                }
              } catch (e) {
                // Ignoriere Parse-Fehler bei unvollständigem JSON
              }
            }
          } else {
            currentObj += char;
          }
        } else {
          currentObj += char;
        }
      }
      
      return cards;
    };

    for await (const chunk of stream) {
      const content = chunk.choices[0]?.delta?.content || "";
      
      if (content) {
        fullContent += content;
        buffer += content;
        
        // Versuche, neue vollständige Karten aus dem Buffer zu parsen
        if (buffer.length > 100) {
          const newCards = tryParsePartialJSON(buffer);
          if (newCards.length > partialCards.length) {
            partialCards = newCards;
            const newCount = partialCards.length;
            yield {
              type: "content",
              message: `KI generiert... (${newCount} Karte${newCount === 1 ? "" : "n"} erkannt)`,
              data: { 
                partial: buffer.substring(0, 100),
                partialCards: partialCards.slice(lastParsedIndex) // Nur neue Karten
              }
            };
            lastParsedIndex = partialCards.length;
          } else {
            yield { 
              type: "content", 
              message: "KI schreibt...",
              data: { partial: buffer.substring(0, 100) }
            };
          }
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

    // Parse JSON Response
    yield { type: "status", message: "Parse JSON-Antwort..." };
    onStatusUpdate?.("Parse JSON-Antwort...");

    // Entferne Markdown-Code-Blöcke falls vorhanden (```json ... ```)
    let jsonContent = fullContent.trim();
    
    // Entferne ```json am Anfang
    if (jsonContent.startsWith("```json")) {
      jsonContent = jsonContent.substring(7).trim();
    } else if (jsonContent.startsWith("```")) {
      jsonContent = jsonContent.substring(3).trim();
    }
    
    // Entferne ``` am Ende
    if (jsonContent.endsWith("```")) {
      jsonContent = jsonContent.substring(0, jsonContent.length - 3).trim();
    }

    let parsed: any;
    try {
      parsed = JSON.parse(jsonContent);
    } catch (e: any) {
      yield { 
        type: "error", 
        message: `JSON Parse Fehler: ${e.message}`,
        data: { rawContent: fullContent.substring(0, 500) }
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
      message: `✓ ${validCards.length} Karte${validCards.length === 1 ? "" : "n"} erfolgreich erstellt` 
    };
    onStatusUpdate?.(`✓ ${validCards.length} Karten erfolgreich erstellt`);

    yield { 
      type: "done", 
      message: "Fertig",
      data: { cards: validCards }
    };
  } catch (error: any) {
    console.error("OpenAI Streaming Error:", error);
    
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
      data: { error: error }
    };
  }
}

