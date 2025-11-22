import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export interface CardGenerationOptions {
  sourceLanguage?: string;
  targetLanguage?: string;
  maxCards?: number;
}

/**
 * Generate flashcards from text content using OpenAI
 */
export async function generateCardsFromText(
  text: string,
  options: CardGenerationOptions = {}
): Promise<Array<{ front: string; back: string; tags?: string }>> {
  if (!process.env.OPENAI_API_KEY) {
    throw new Error("OpenAI API key not configured");
  }

  const sourceLang = options.sourceLanguage || "German";
  const targetLang = options.targetLanguage || "English";
  const maxCards = options.maxCards || 20;

  // Split text into chunks if too long (OpenAI has token limits)
  const chunks = chunkText(text, 3000);

  const allCards: Array<{ front: string; back: string; tags?: string }> = [];

  for (const chunk of chunks) {
    const prompt = `You are a vocabulary learning assistant. Extract vocabulary words and phrases from the following text and create flashcards.

Text:
${chunk}

Instructions:
1. Create flashcards with ${sourceLang} words/phrases on the front and ${targetLang} translations/explanations on the back
2. Extract important vocabulary, not every single word
3. Focus on words that are useful for learning
4. Add relevant tags (e.g., topic, difficulty level)
5. Create maximum ${maxCards} cards from this text chunk
6. Return ONLY a JSON array in this exact format:
[
  {
    "front": "German word or phrase",
    "back": "English translation or explanation",
    "tags": "tag1, tag2, tag3"
  }
]

Return only the JSON array, no other text:`;

    try {
      const response = await openai.chat.completions.create({
        model: "gpt-4-turbo-preview",
        messages: [
          {
            role: "system",
            content:
              "You are a helpful assistant that creates vocabulary flashcards from text. Always return valid JSON arrays only.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        temperature: 0.7,
        max_tokens: 2000,
      });

      const content = response.choices[0]?.message?.content;
      if (!content) {
        continue;
      }

      // Parse JSON response
      const jsonMatch = content.match(/\[[\s\S]*\]/);
      if (jsonMatch) {
        const cards = JSON.parse(jsonMatch[0]);
        allCards.push(...cards);
      }
    } catch (error) {
      console.error("Error generating cards from OpenAI:", error);
      // Continue with next chunk
    }
  }

  // Limit total cards
  return allCards.slice(0, maxCards);
}

/**
 * Split text into chunks of approximately maxLength characters
 */
function chunkText(text: string, maxLength: number): string[] {
  const chunks: string[] = [];
  let currentChunk = "";

  const sentences = text.split(/[.!?]\s+/);

  for (const sentence of sentences) {
    if (currentChunk.length + sentence.length > maxLength && currentChunk) {
      chunks.push(currentChunk.trim());
      currentChunk = sentence;
    } else {
      currentChunk += (currentChunk ? ". " : "") + sentence;
    }
  }

  if (currentChunk) {
    chunks.push(currentChunk.trim());
  }

  return chunks.length > 0 ? chunks : [text];
}

