const MS_PER_DAY = 1000 * 60 * 60 * 24;

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

const defaultConfig = {
  // Request retention determines how "tight" intervals stay to reach the target recall probability.
  requestRetention: 0.9,
  maximumInterval: 365,
  // Weights tuned to be close to FSRS-5 defaults. They can be tweaked later if you retrain.
  weights: {
    initStability: 0.4,
    initDifficulty: 5.8,
    stabilityGrowth: 3.0,
    stabilityDecay: 0.6,
    difficultyDecay: 0.25,
    difficultyStep: 0.6,
    easyBonus: 1.3,
    hardPenalty: 0.5,
    lapseReset: 0.2
  }
};

const createInitialScheduling = (now = new Date()) => ({
  stability: defaultConfig.weights.initStability,
  difficulty: defaultConfig.weights.initDifficulty,
  due: now,
  lastReview: now,
  lapses: 0,
  reps: 0
});

const calculateNext = (card, rating, now = new Date()) => {
  const { weights, requestRetention, maximumInterval } = defaultConfig;
  const last = card.lastReview ? new Date(card.lastReview) : now;
  const elapsedDays = Math.max(0.04, (now - last) / MS_PER_DAY); // minimum 1 hour to avoid zero division

  // Expected retrievability before this review
  const retrievability = Math.exp(Math.log(requestRetention) * elapsedDays / Math.max(card.stability || 0.01, 0.01));

  // Update difficulty (FSRS keeps difficulty bounded 1..10)
  let difficulty = clamp(
    card.difficulty + weights.difficultyStep * (3 - rating),
    1,
    10
  );

  let stability;
  let lapses = card.lapses || 0;

  if (rating === 1) {
    // Forgot: reset stability down, count lapse
    stability = weights.lapseReset;
    difficulty = clamp(difficulty + weights.difficultyDecay, 1, 10);
    lapses += 1;
  } else {
    const performance = Math.pow(retrievability, weights.stabilityDecay);
    const adj = rating === 4 ? weights.easyBonus : rating === 2 ? -weights.hardPenalty : 1;
    stability =
      (card.stability || weights.initStability) *
      (1 + weights.stabilityGrowth * (1 - performance) * adj);
  }

  const interval = clamp(
    Math.round(stability * Math.log(1 / (1 - requestRetention))),
    1,
    maximumInterval
  );

  return {
    stability,
    difficulty,
    due: new Date(now.getTime() + interval * MS_PER_DAY),
    lastReview: now,
    lapses,
    reps: (card.reps || 0) + 1,
    intervalDays: interval
  };
};

module.exports = {
  defaultConfig,
  createInitialScheduling,
  calculateNext
};
