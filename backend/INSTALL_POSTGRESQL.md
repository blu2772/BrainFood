# PostgreSQL Installation auf Ubuntu Server

Diese Anleitung zeigt, wie du PostgreSQL auf einem Ubuntu-Server installierst (z.B. für Plesk).

## Installation

### 1. System aktualisieren

```bash
sudo apt update
sudo apt upgrade -y
```

### 2. PostgreSQL installieren

```bash
sudo apt install postgresql postgresql-contrib -y
```

### 3. PostgreSQL Status prüfen

```bash
sudo systemctl status postgresql
```

PostgreSQL sollte automatisch gestartet sein. Falls nicht:

```bash
sudo systemctl start postgresql
sudo systemctl enable postgresql  # Startet automatisch beim Boot
```

## Konfiguration

### 4. PostgreSQL-Benutzer erstellen

Standardmäßig erstellt PostgreSQL einen Benutzer namens `postgres`. Du kannst direkt damit arbeiten oder einen neuen Benutzer erstellen:

```bash
# Als postgres-Benutzer einloggen
sudo -u postgres psql
```

Im PostgreSQL-Prompt:

```sql
-- Neuen Benutzer erstellen
CREATE USER brainfood_user WITH PASSWORD 'dein_sicheres_passwort';

-- Datenbank erstellen
CREATE DATABASE brainfood;

-- Berechtigungen vergeben
GRANT ALL PRIVILEGES ON DATABASE brainfood TO brainfood_user;

-- PostgreSQL verlassen
\q
```

### 5. PostgreSQL für Remote-Zugriff konfigurieren (optional)

Falls du von außen auf die Datenbank zugreifen möchtest:

**a) `postgresql.conf` bearbeiten:**

```bash
sudo nano /etc/postgresql/*/main/postgresql.conf
```

Suche nach `listen_addresses` und ändere es zu:

```
listen_addresses = '*'  # oder spezifische IP
```

**b) `pg_hba.conf` bearbeiten:**

```bash
sudo nano /etc/postgresql/*/main/pg_hba.conf
```

Füge am Ende hinzu:

```
host    brainfood    brainfood_user    0.0.0.0/0    md5
```

**c) PostgreSQL neu starten:**

```bash
sudo systemctl restart postgresql
```

## Verbindung testen

### 6. Lokale Verbindung testen

```bash
psql -U brainfood_user -d brainfood -h localhost
```

Oder mit dem postgres-Benutzer:

```bash
sudo -u postgres psql -d brainfood
```

## Für BrainFood Backend

### 7. DATABASE_URL in .env setzen

Erstelle oder bearbeite `backend/.env`:

```env
DATABASE_URL="postgresql://brainfood_user:dein_sicheres_passwort@localhost:5432/brainfood?schema=public"
```

**Wichtig:** Ersetze `dein_sicheres_passwort` mit dem tatsächlichen Passwort!

### 8. Prisma Migrationen ausführen

```bash
cd backend
npm install
npm run generate
npm run migrate
```

## Firewall (falls aktiv)

Falls du eine Firewall verwendest (z.B. UFW), öffne Port 5432:

```bash
sudo ufw allow 5432/tcp
sudo ufw reload
```

## Alternative: PostgreSQL über Plesk installieren

Falls du Plesk verwendest:

1. **Plesk Extension Catalog:**
   - Gehe zu Extensions → Catalog
   - Suche nach "PostgreSQL"
   - Installiere die PostgreSQL Extension

2. **Oder über Plesk Database Server:**
   - Gehe zu Tools & Settings → Database Servers
   - PostgreSQL sollte dort aufgelistet sein
   - Falls nicht, installiere es über den Server

## Troubleshooting

### PostgreSQL läuft nicht

```bash
# Status prüfen
sudo systemctl status postgresql

# Logs ansehen
sudo journalctl -u postgresql -n 50

# Neu starten
sudo systemctl restart postgresql
```

### Verbindungsfehler

- Prüfe, ob PostgreSQL läuft: `sudo systemctl status postgresql`
- Prüfe die Firewall-Regeln
- Prüfe die `pg_hba.conf` Konfiguration
- Prüfe die `postgresql.conf` für `listen_addresses`

### Passwort zurücksetzen

```bash
sudo -u postgres psql
```

```sql
ALTER USER brainfood_user WITH PASSWORD 'neues_passwort';
\q
```

## Sicherheitstipps

1. **Starke Passwörter verwenden**
2. **Nur notwendige Ports öffnen**
3. **Regelmäßige Backups erstellen**
4. **SSL/TLS für Remote-Verbindungen aktivieren**

## Backup & Restore

**Backup erstellen:**
```bash
sudo -u postgres pg_dump brainfood > backup.sql
```

**Backup wiederherstellen:**
```bash
sudo -u postgres psql brainfood < backup.sql
```

---

**Fertig!** PostgreSQL ist jetzt installiert und konfiguriert. Du kannst jetzt das BrainFood Backend mit der Datenbank verbinden.

