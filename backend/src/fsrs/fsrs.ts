import { CardState, FSRSResult, ReviewRating, FSRS_PARAMS } from "./types";

/**
 * FSRS-5 Algorithm Implementation
 * 
 * This implementation follows the Free Spaced Repetition Scheduler v5 algorithm
 * which optimizes review scheduling for a target retention rate (default: 90%).
 */

/**
 * Calculate the next review state based on the current card state and user rating
 */
export function scheduleNextReview(
  cardState: CardState,
  rating: ReviewRating,
  now: Date = new Date()
): FSRSResult {
  const { stability, difficulty, reps, lapses } = cardState;
  
  // Convert rating to numeric value (1-4)
  const ratingValue = ratingToNumber(rating);
  
  // Calculate new difficulty
  const newDifficulty = calculateDifficulty(difficulty, ratingValue);
  
  // Calculate new stability based on rating
  let newStability: number;
  let newReps = reps;
  let newLapses = lapses;
  
  if (rating === "again") {
    // Card was forgotten - reset stability and increment lapses
    newStability = calculateAgainStability(stability, difficulty);
    newLapses = lapses + 1;
    newReps = 0;
  } else {
    // Card was remembered - increase stability
    newStability = calculateStability(stability, difficulty, ratingValue, reps);
    newReps = reps + 1;
  }
  
  // Calculate interval based on new stability and requested retention
  const interval = calculateInterval(newStability, FSRS_PARAMS.requestRetention);
  
  // Calculate next due date
  const newDue = new Date(now.getTime() + interval * 24 * 60 * 60 * 1000);
  
  return {
    newState: {
      stability: newStability,
      difficulty: newDifficulty,
      reps: newReps,
      lapses: newLapses,
      lastReviewAt: now,
      due: newDue,
    },
    interval: Math.round(interval),
  };
}

/**
 * Convert rating string to numeric value
 */
function ratingToNumber(rating: ReviewRating): number {
  switch (rating) {
    case "again": return 1;
    case "hard": return 2;
    case "good": return 3;
    case "easy": return 4;
  }
}

/**
 * Calculate new difficulty based on current difficulty and rating
 */
function calculateDifficulty(currentDifficulty: number, rating: number): number {
  // Difficulty adjustment based on rating
  // Hard ratings increase difficulty, Easy ratings decrease it
  let change = 0;
  
  if (rating === 1) { // again
    change = -0.15;
  } else if (rating === 2) { // hard
    change = 0.1;
  } else if (rating === 3) { // good
    change = 0;
  } else if (rating === 4) { // easy
    change = -0.1;
  }
  
  const newDifficulty = currentDifficulty + change;
  
  // Clamp difficulty between 0 and 1
  return Math.max(0, Math.min(1, newDifficulty));
}

/**
 * Calculate stability when card is rated "again" (forgotten)
 */
function calculateAgainStability(stability: number, difficulty: number): number {
  // When forgotten, stability drops significantly
  // Formula based on FSRS-5 algorithm
  const factor = 0.15 + (difficulty * 0.1);
  return stability * factor;
}

/**
 * Calculate new stability when card is remembered
 */
function calculateStability(
  currentStability: number,
  difficulty: number,
  rating: number,
  reps: number
): number {
  // Base multiplier based on rating
  let multiplier = 1;
  
  if (rating === 2) { // hard
    multiplier = 1.2;
  } else if (rating === 3) { // good
    multiplier = 2.5;
  } else if (rating === 4) { // easy
    multiplier = 4.0;
  }
  
  // Adjust for difficulty (harder cards grow slower)
  const difficultyFactor = 1 - (difficulty * 0.2);
  
  // Adjust for number of reviews (more reviews = slower growth)
  const repsFactor = 1 + (reps * 0.05);
  
  return currentStability * multiplier * difficultyFactor * (1 / repsFactor);
}

/**
 * Calculate review interval in days based on stability and requested retention
 */
function calculateInterval(stability: number, requestRetention: number): number {
  // Calculate interval using exponential function
  // Higher stability = longer intervals
  // Higher retention target = shorter intervals
  
  const retentionFactor = Math.log(requestRetention) / Math.log(0.9);
  const interval = stability * retentionFactor;
  
  // Clamp interval between 1 day and maximum interval
  return Math.max(1, Math.min(interval, FSRS_PARAMS.maximumInterval));
}

/**
 * Initialize a new card with default FSRS-5 state
 */
export function initializeCardState(): CardState {
  return {
    stability: FSRS_PARAMS.initialStability,
    difficulty: FSRS_PARAMS.initialDifficulty,
    reps: 0,
    lapses: 0,
    lastReviewAt: null,
    due: new Date(), // Due immediately for first review
  };
}

