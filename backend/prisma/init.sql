-- BrainFood Database Schema
-- Führe diese Datei direkt in PostgreSQL aus, falls Migrationen nicht funktionieren

-- Tabelle: users
CREATE TABLE IF NOT EXISTS "users" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- Tabelle: boxes
CREATE TABLE IF NOT EXISTS "boxes" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "boxes_pkey" PRIMARY KEY ("id")
);

-- Tabelle: cards
CREATE TABLE IF NOT EXISTS "cards" (
    "id" TEXT NOT NULL,
    "box_id" TEXT NOT NULL,
    "front" TEXT NOT NULL,
    "back" TEXT NOT NULL,
    "tags" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "stability" DOUBLE PRECISION NOT NULL DEFAULT 0.4,
    "difficulty" DOUBLE PRECISION NOT NULL DEFAULT 0.3,
    "reps" INTEGER NOT NULL DEFAULT 0,
    "lapses" INTEGER NOT NULL DEFAULT 0,
    "last_review_at" TIMESTAMP(3),
    "due" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cards_pkey" PRIMARY KEY ("id")
);

-- Tabelle: review_logs
CREATE TABLE IF NOT EXISTS "review_logs" (
    "id" TEXT NOT NULL,
    "card_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "rating" TEXT NOT NULL,
    "reviewed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "previous_stability" DOUBLE PRECISION NOT NULL,
    "new_stability" DOUBLE PRECISION NOT NULL,
    "previous_due" TIMESTAMP(3) NOT NULL,
    "new_due" TIMESTAMP(3) NOT NULL,
    "interval" INTEGER,

    CONSTRAINT "review_logs_pkey" PRIMARY KEY ("id")
);

-- Unique Constraints
CREATE UNIQUE INDEX IF NOT EXISTS "users_email_key" ON "users"("email");

-- Foreign Keys
ALTER TABLE "boxes" ADD CONSTRAINT "boxes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "cards" ADD CONSTRAINT "cards_box_id_fkey" FOREIGN KEY ("box_id") REFERENCES "boxes"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "review_logs" ADD CONSTRAINT "review_logs_card_id_fkey" FOREIGN KEY ("card_id") REFERENCES "cards"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "review_logs" ADD CONSTRAINT "review_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

