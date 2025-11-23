import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

/**
 * Generiert Karteikarten aus Text mit OpenAI
 */
export async function generateCardsFromText(
  text: string,
  sourceLanguage: string = "Deutsch",
  targetLanguage: string = "Englisch"
): Promise<Array<{ front: string; back: string; tags?: string }>> {
  if (!process.env.OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY is not set");
  }

  const prompt = `Du bist ein Experte für das Erstellen von Vokabelkarten. 
Erstelle aus dem folgenden Text Vokabelkarten im Format:
- Front: Das zu lernende Wort/Phrase in ${sourceLanguage}
- Back: Die Übersetzung/Erklärung in ${targetLanguage}
- Tags: Relevante Themen/Kategorien (optional, kommagetrennt)

Text:
${text}

Antworte NUR mit einem JSON-Array im folgenden Format:
[
  {
    "front": "Wort in ${sourceLanguage}",
    "back": "Übersetzung in ${targetLanguage}",
    "tags": "tag1, tag2"
  }
]

Erstelle so viele Karten wie sinnvoll möglich. Fokussiere dich auf wichtige Vokabeln und Phrasen.`;

  try {
    const completion = await openai.chat.completions.create({
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
      response_format: { type: "json_object" },
    });

    const responseContent = completion.choices[0]?.message?.content;
    if (!responseContent) {
      throw new Error("No response from OpenAI");
    }

    // Parse JSON Response
    let parsed: any;
    try {
      parsed = JSON.parse(responseContent);
    } catch (e) {
      // Falls die Antwort direkt ein Array ist
      parsed = JSON.parse(responseContent);
    }

    // Normalisiere das Format (kann Objekt mit "cards" Array oder direkt Array sein)
    let cards: Array<{ front: string; back: string; tags?: string }> = [];
    if (Array.isArray(parsed)) {
      cards = parsed;
    } else if (parsed.cards && Array.isArray(parsed.cards)) {
      cards = parsed.cards;
    } else if (parsed.data && Array.isArray(parsed.data)) {
      cards = parsed.data;
    }

    return cards.map((card) => ({
      front: card.front || "",
      back: card.back || "",
      tags: card.tags || "",
    }));
  } catch (error: any) {
    console.error("OpenAI API Error:", error);
    throw new Error(`Failed to generate cards: ${error.message}`);
  }
}

