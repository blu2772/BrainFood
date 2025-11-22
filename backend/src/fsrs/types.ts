/**
 * FSRS-5 Algorithm Types
 * Based on the Free Spaced Repetition Scheduler v5 algorithm
 */

export type ReviewRating = "again" | "hard" | "good" | "easy";

export interface CardState {
  stability: number; // Current stability in days
  difficulty: number; // Difficulty factor (0-1)
  reps: number; // Number of successful reviews
  lapses: number; // Number of times rated "again"
  lastReviewAt: Date | null; // Last review timestamp
  due: Date; // Next review due date
}

export interface FSRSResult {
  newState: CardState;
  interval: number; // Interval in days until next review
}

/**
 * FSRS-5 Parameters
 * These are optimized parameters for a 90% retention target
 */
export const FSRS_PARAMS = {
  // Requested retention (target probability of recall)
  requestRetention: 0.9,
  
  // Maximum interval in days
  maximumInterval: 36500,
  
  // Weights for different rating transitions
  w: [
    0.4, 0.6, 2.4, 5.8, 4.93, 0.94, 0.86, 0.01, 1.49, 0.14, 0.94, 2.18, 0.05, 0.34, 1.26, 0.29, 2.61
  ],
  
  // Initial stability for new cards
  initialStability: 0.4,
  
  // Initial difficulty
  initialDifficulty: 0.3,
};

