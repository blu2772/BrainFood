# Prisma Migrate Berechtigungen beheben

## Problem
Der PostgreSQL-Benutzer hat keine Berechtigung, Datenbanken zu erstellen (für Shadow-Datenbank).

## Lösung 1: Berechtigung erteilen (Empfohlen für Entwicklung)

### Als postgres-Superuser einloggen:
```bash
sudo -u postgres psql
```

### Im PostgreSQL-Prompt:
```sql
-- Berechtigung zum Erstellen von Datenbanken erteilen
ALTER USER brainfood_user CREATEDB;

-- Oder falls du den postgres-Benutzer verwendest:
ALTER USER postgres CREATEDB;

-- Verlassen
\q
```

## Lösung 2: Shadow-Datenbank deaktivieren (Für Produktion)

Falls du keine Berechtigung erteilen kannst oder willst, kannst du die Shadow-Datenbank deaktivieren.

### In `prisma/schema.prisma`:
```prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
  shadowDatabaseUrl = env("SHADOW_DATABASE_URL")  // Optional: separate Shadow-DB
}
```

### Oder in `.env` eine separate Shadow-Datenbank angeben:
```env
DATABASE_URL="postgresql://brainfood_user:passwort@localhost:5432/brainfood?schema=public"
SHADOW_DATABASE_URL="postgresql://brainfood_user:passwort@localhost:5432/brainfood_shadow?schema=public"
```

### Oder Shadow-Datenbank komplett deaktivieren:
Führe Migrationen mit `--skip-seed` und `--create-only` aus, oder verwende `prisma migrate deploy` statt `prisma migrate dev`.

## Lösung 3: Migrationen ohne Shadow-Datenbank (Produktion)

Für Produktion verwende `migrate deploy` statt `migrate dev`:

```bash
npm run migrate:deploy
```

Dies erfordert keine Shadow-Datenbank.

## Schnelllösung

Falls du schnell weitermachen willst, gib dem Benutzer die Berechtigung:

```bash
sudo -u postgres psql -c "ALTER USER brainfood_user CREATEDB;"
```

Oder falls du den `postgres`-Benutzer verwendest:

```bash
sudo -u postgres psql -c "ALTER USER postgres CREATEDB;"
```

