import pdfParse from "pdf-parse";
import { generateCardsFromText } from "./openaiService";

/**
 * Extract text from PDF buffer
 */
export async function extractTextFromPDF(
  pdfBuffer: Buffer
): Promise<string> {
  try {
    const data = await pdfParse(pdfBuffer);
    return data.text;
  } catch (error) {
    throw new Error(`Failed to parse PDF: ${error}`);
  }
}

/**
 * Generate flashcards from PDF
 */
export async function generateCardsFromPDF(
  pdfBuffer: Buffer,
  options: { sourceLanguage?: string; targetLanguage?: string; maxCards?: number } = {}
): Promise<Array<{ front: string; back: string; tags?: string }>> {
  const text = await extractTextFromPDF(pdfBuffer);
  
  if (!text || text.trim().length === 0) {
    throw new Error("PDF contains no extractable text");
  }

  return generateCardsFromText(text, options);
}

