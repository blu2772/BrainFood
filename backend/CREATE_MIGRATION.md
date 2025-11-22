# Migrationen erstellen und auf Server deployen

## Problem
- Keine Migrationen vorhanden
- Datenbank-Verbindung auf Server hat Timeout

## Lösung: Migrationen lokal erstellen

### 1. Lokal (auf deinem Mac):

```bash
cd backend

# Stelle sicher, dass DATABASE_URL auf lokale DB zeigt (oder SQLite für Migration)
# Temporär in .env ändern zu einer funktionierenden DB

# Erstelle Migration
npm run migrate

# Oder explizit:
npx prisma migrate dev --name init
```

### 2. Migrationen-Dateien hochladen

Die Migrationen werden in `prisma/migrations/` erstellt. Lade diesen gesamten Ordner auf den Server hoch.

### 3. Auf dem Server:

```bash
cd /var/www/vhosts/timrmp.de/BrainFood.timrmp.de/backend

# Prisma Client generieren
npm run generate

# Migrationen deployen (ohne Shadow-DB)
npx prisma migrate deploy
```

## Alternative: SQL direkt ausführen

Falls Migrationen nicht funktionieren, kannst du die SQL-Dateien aus `prisma/migrations/` direkt in PostgreSQL ausführen:

```bash
sudo -u postgres psql -d brainfood -f migration.sql
```

## Schnelllösung: Prisma db push (für Entwicklung)

```bash
npx prisma db push
```

**Warnung:** `db push` erstellt keine Migrationen, sondern synchronisiert direkt das Schema. Nur für Entwicklung geeignet!

