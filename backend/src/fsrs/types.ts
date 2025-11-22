/**
 * FSRS-5 Algorithmus Typen
 * 
 * FSRS (Free Spaced Repetition Scheduler) ist ein Algorithmus zur optimalen
 * Planung von Wiederholungen basierend auf der Vergessenskurve.
 */

export type ReviewRating = "again" | "hard" | "good" | "easy";

export interface CardState {
  stability: number;      // Stabilität des Gedächtnisses (in Tagen)
  difficulty: number;     // Schwierigkeit der Karte (0-1)
  reps: number;          // Anzahl erfolgreicher Wiederholungen
  lapses: number;        // Anzahl Fehler
  lastReviewAt: Date | null; // Letztes Review-Datum
  due: Date;             // Nächstes Fälligkeitsdatum
}

export interface FSRSResult {
  newState: CardState;
  interval: number;      // Neues Intervall in Tagen
  nextDue: Date;         // Nächstes Fälligkeitsdatum
}

/**
 * FSRS-5 Parameter
 * Diese Werte basieren auf der FSRS-5 Forschung und können angepasst werden
 */
export const FSRS_PARAMS = {
  // Request Retention (Ziel-Erinnerungswahrscheinlichkeit)
  REQUEST_RETENTION: 0.9,
  
  // Maximum Interval (maximales Intervall in Tagen)
  MAXIMUM_INTERVAL: 36500,
  
  // Weights für verschiedene Rating-Kombinationen
  // Format: [w[0], w[1], ..., w[14]] für verschiedene Szenarien
  WEIGHTS: [
    0.4, 0.6, 2.4, 5.8, 4.93, 0.94, 0.86, 0.01, 1.49, 0.14, 0.94, 2.18, 0.05, 0.34, 1.26
  ],
  
  // Difficulty Decay
  DIFFICULTY_DECAY: 0.3,
  
  // Stability Increase Factors
  STABILITY_INCREASE_AGAIN: 0.15,
  STABILITY_INCREASE_HARD: 0.4,
  STABILITY_INCREASE_GOOD: 1.0,
  STABILITY_INCREASE_EASY: 1.3,
};

