import { CardState, FSRSResult, ReviewRating, FSRS_PARAMS } from "./types";

/**
 * FSRS-5 Algorithmus Implementation
 * 
 * Basierend auf dem Free Spaced Repetition Scheduler Algorithmus
 * für optimale Wiederholungsplanung von Lernkarten.
 */

/**
 * Berechnet die neue Stabilität basierend auf Rating und aktuellem State
 */
function calculateNewStability(
  currentStability: number,
  difficulty: number,
  rating: ReviewRating
): number {
  const easyBonus = 1.3;
  
  let stabilityIncrease: number;
  
  switch (rating) {
    case "again":
      // Bei "Again" wird die Stabilität stark reduziert
      return Math.max(0.1, currentStability * FSRS_PARAMS.STABILITY_INCREASE_AGAIN);
    
    case "hard":
      // Bei "Hard" wächst die Stabilität wenig
      stabilityIncrease = FSRS_PARAMS.STABILITY_INCREASE_HARD;
      return currentStability * (1 + Math.exp(-8 + 0.12 * difficulty)) * stabilityIncrease;
    
    case "good":
      // Standard-Wachstum
      stabilityIncrease = FSRS_PARAMS.STABILITY_INCREASE_GOOD;
      return currentStability * (1 + Math.exp(-8 + 0.12 * difficulty)) * stabilityIncrease;
    
    case "easy":
      // Größeres Intervall, stärkeres Wachstum
      stabilityIncrease = FSRS_PARAMS.STABILITY_INCREASE_EASY;
      return currentStability * (1 + Math.exp(-8 + 0.12 * difficulty)) * stabilityIncrease * easyBonus;
    
    default:
      return currentStability;
  }
}

/**
 * Berechnet die neue Schwierigkeit basierend auf Rating
 */
function calculateNewDifficulty(
  currentDifficulty: number,
  rating: ReviewRating
): number {
  let difficultyChange: number;
  
  switch (rating) {
    case "again":
      difficultyChange = -0.2;
      break;
    case "hard":
      difficultyChange = -0.15;
      break;
    case "good":
      difficultyChange = 0;
      break;
    case "easy":
      difficultyChange = 0.15;
      break;
    default:
      difficultyChange = 0;
  }
  
  const newDifficulty = currentDifficulty + difficultyChange;
  
  // Schwierigkeit auf Bereich [0, 1] begrenzen
  return Math.max(0, Math.min(1, newDifficulty));
}

/**
 * Berechnet das neue Intervall basierend auf Stabilität und Rating
 */
function calculateInterval(
  stability: number,
  rating: ReviewRating
): number {
  // Basis-Intervall basierend auf Stabilität
  let interval = stability;
  
  // Anpassung basierend auf Rating
  switch (rating) {
    case "again":
      // Sehr kurzes Intervall (1 Tag)
      interval = 1;
      break;
    case "hard":
      // Kürzeres Intervall (75% der Stabilität)
      interval = stability * 0.75;
      break;
    case "good":
      // Standard-Intervall (100% der Stabilität)
      interval = stability;
      break;
    case "easy":
      // Längeres Intervall (130% der Stabilität)
      interval = stability * 1.3;
      break;
  }
  
  // Intervall auf Maximum begrenzen
  interval = Math.min(interval, FSRS_PARAMS.MAXIMUM_INTERVAL);
  
  // Auf ganze Tage runden
  return Math.max(1, Math.round(interval));
}

/**
 * Hauptfunktion: Plant die nächste Wiederholung basierend auf FSRS-5
 * 
 * @param cardState Aktueller Zustand der Karte
 * @param rating Bewertung durch den Benutzer (again/hard/good/easy)
 * @param now Aktuelles Datum/Zeit
 * @returns Neuer Zustand und nächstes Fälligkeitsdatum
 */
export function scheduleNextReview(
  cardState: CardState,
  rating: ReviewRating,
  now: Date = new Date()
): FSRSResult {
  // Neue Stabilität berechnen
  const newStability = calculateNewStability(
    cardState.stability,
    cardState.difficulty,
    rating
  );
  
  // Neue Schwierigkeit berechnen
  const newDifficulty = calculateNewDifficulty(cardState.difficulty, rating);
  
  // Neue Reps und Lapses aktualisieren
  let newReps = cardState.reps;
  let newLapses = cardState.lapses;
  
  if (rating === "again") {
    newLapses += 1;
    newReps = 0; // Reset bei Fehler
  } else {
    newReps += 1;
  }
  
  // Neues Intervall berechnen
  const interval = calculateInterval(newStability, rating);
  
  // Nächstes Fälligkeitsdatum berechnen
  const nextDue = new Date(now);
  nextDue.setDate(nextDue.getDate() + interval);
  
  // Neuen State erstellen
  const newState: CardState = {
    stability: newStability,
    difficulty: newDifficulty,
    reps: newReps,
    lapses: newLapses,
    lastReviewAt: now,
    due: nextDue,
  };
  
  return {
    newState,
    interval,
    nextDue,
  };
}

/**
 * Initialisiert einen neuen Card-State für eine neue Karte
 */
export function initializeCardState(): CardState {
  return {
    stability: 0.4,      // Initiale Stabilität (ca. 1 Tag)
    difficulty: 0.3,    // Mittlere Schwierigkeit
    reps: 0,
    lapses: 0,
    lastReviewAt: null,
    due: new Date(),    // Sofort fällig für erste Wiederholung
  };
}

/**
 * Prüft, ob eine Karte fällig ist
 */
export function isCardDue(cardState: CardState, now: Date = new Date()): boolean {
  return cardState.due <= now;
}

