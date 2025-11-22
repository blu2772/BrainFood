-- Migration für API Keys Tabelle
-- Führe diese Datei aus, um die api_keys Tabelle zu erstellen

CREATE TABLE IF NOT EXISTS "api_keys" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "key_prefix" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_used_at" TIMESTAMP(3),

    CONSTRAINT "api_keys_pkey" PRIMARY KEY ("id")
);

-- Unique Constraint für Key
CREATE UNIQUE INDEX IF NOT EXISTS "api_keys_key_key" ON "api_keys"("key");

-- Foreign Key
ALTER TABLE "api_keys" ADD CONSTRAINT "api_keys_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

