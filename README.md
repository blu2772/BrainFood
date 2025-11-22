# BrainFood - Vokabel-Lern-App mit FSRS-5

BrainFood ist eine moderne iOS-Vokabel-App, die den **FSRS-5 Algorithmus** (Free Spaced Repetition Scheduler v5) zur intelligenten Lernplanung nutzt. Die App ermöglicht effizientes Lernen von Vokabeln über Boxen und Karteikarten, unterstützt PDF-Import mit OpenAI-gestützter Kartenerstellung und bietet ein vollständiges Backend mit REST-API.

## 🎯 Features

- **FSRS-5 Algorithmus**: Intelligente Wiederholungsplanung für optimale Lernzeiten
- **Box-System**: Organisiere deine Vokabeln in verschiedenen Boxen
- **Karteikarten**: Erstelle und verwalte Vokabelkarten mit Front/Back und Tags
- **Lern-Interface**: Intuitives Review-System mit Bewertungen (Again/Hard/Good/Easy)
- **PDF-Import**: Automatische Kartenerstellung aus PDF-Dateien mit OpenAI
- **Text-Import**: Generiere Karten aus beliebigem Text
- **Statistiken**: Übersicht über Lernfortschritt und fällige Karten
- **Offline-Fähigkeit**: Lokales Caching für Offline-Nutzung
- **REST-API**: Vollständige Backend-API für alle Funktionen
- **OpenAPI-Schema**: Kompatibel mit OpenAI Custom GPT Actions

## 📁 Projektstruktur

```
BrainFood/
├── backend/              # Node.js/TypeScript Backend-Server
│   ├── src/
│   │   ├── fsrs/        # FSRS-5 Algorithmus-Implementierung
│   │   ├── routes/      # Express-Routen (Auth, Boxes, Cards, Reviews, etc.)
│   │   ├── services/    # OpenAI-Service, PDF-Service
│   │   ├── middleware/  # JWT-Authentifizierung
│   │   └── utils/       # Hilfsfunktionen
│   ├── prisma/          # Datenbank-Schema und Migrationen
│   ├── openapi.yaml     # OpenAPI-Spezifikation für Custom GPT
│   └── package.json
│
└── IOS App/             # iOS-App (Swift/SwiftUI)
    └── BrainFood/
        └── BrainFood/
            ├── Models/      # Datenmodelle (User, Box, Card, etc.)
            ├── Services/     # API-Client, Keychain-Service
            ├── ViewModels/   # MVVM ViewModels
            ├── Views/        # SwiftUI Views
            └── BrainFoodApp.swift  # App Entry Point
```

## 🚀 Installation & Setup

### Voraussetzungen

**Backend:**
- Node.js 18+ und npm
- PostgreSQL 12+ (oder SQLite für lokale Entwicklung)
- OpenAI API-Key (für PDF/Text-Import)

**iOS-App:**
- Xcode 15+
- iOS 17+ SDK
- macOS (für Entwicklung)

---

## 🔧 Backend Setup

### 1. Repository klonen und Backend-Verzeichnis öffnen

```bash
cd backend
```

### 2. Dependencies installieren

```bash
npm install
```

### 3. Umgebungsvariablen konfigurieren

Erstelle eine `.env`-Datei im `backend/`-Verzeichnis:

```env
# Datenbank
DATABASE_URL="postgresql://user:password@localhost:5432/brainfood?schema=public"

# JWT
JWT_SECRET="dein-super-geheimer-jwt-schlüssel-ändere-dies-in-produktion"
JWT_EXPIRES_IN="12h"

# OpenAI
OPENAI_API_KEY="sk-dein-openai-api-key-hier"

# Server
PORT=3000
NODE_ENV=development
```

**Hinweis:** Für lokale Entwicklung mit SQLite kannst du `DATABASE_URL="file:./dev.db"` verwenden (dann in `prisma/schema.prisma` `provider = "sqlite"` setzen).

### 4. Datenbank-Migrationen ausführen

```bash
# Prisma Client generieren
npm run generate

# Migrationen erstellen und anwenden
npm run migrate
```

### 5. Server starten

**Entwicklung (mit Hot-Reload):**
```bash
npm run dev
```

**Produktion:**
```bash
npm run build
npm run start
```

Der Server läuft dann auf `http://localhost:3000` (oder dem in `.env` konfigurierten PORT).

### 6. API testen

Die API ist unter `http://localhost:3000/api` erreichbar. Ein Health-Check-Endpoint:

```bash
curl http://localhost:3000/health
```

---

## 📱 iOS-App Setup

### 1. Xcode-Projekt öffnen

Öffne `IOS App/BrainFood/BrainFood.xcodeproj` in Xcode.

### 2. Backend-URL konfigurieren

Öffne `IOS App/BrainFood/BrainFood/Services/APIClient.swift` und passe die `baseURL` an:

```swift
private let baseURL: String = "http://localhost:3000/api"  // Lokal
// oder für Produktion:
// private let baseURL: String = "https://deine-domain.com/api"
```

**Wichtig für iOS-Simulator:** `localhost` funktioniert. Für physische Geräte musst du die IP-Adresse deines Computers verwenden (z.B. `http://192.168.1.100:3000/api`).

### 3. App bauen und ausführen

- Wähle ein iOS-Simulator oder physisches Gerät
- Drücke `Cmd+R` zum Builden und Ausführen

---

## 🔐 Authentifizierung

Die API nutzt **JWT (JSON Web Token)** für die Authentifizierung. Nach erfolgreichem Login/Registrierung erhältst du ein Token, das in allen nachfolgenden Requests im `Authorization`-Header mitgesendet werden muss:

```
Authorization: Bearer <token>
```

Die Token-Gültigkeit beträgt standardmäßig **12 Stunden** (konfigurierbar über `JWT_EXPIRES_IN`).

---

## 📚 API-Endpunkte

### Authentifizierung

- `POST /api/auth/register` - Neuen Benutzer registrieren
- `POST /api/auth/login` - Einloggen
- `GET /api/auth/me` - Aktuellen Benutzer abrufen
- `POST /api/auth/logout` - Ausloggen (client-seitig)

### Boxen

- `GET /api/boxes` - Alle Boxen des Benutzers
- `POST /api/boxes` - Neue Box erstellen
- `PUT /api/boxes/:boxId` - Box aktualisieren
- `DELETE /api/boxes/:boxId` - Box löschen

### Karten

- `GET /api/boxes/:boxId/cards` - Alle Karten einer Box (optional: `?search=...&sort=due`)
- `POST /api/boxes/:boxId/cards` - Neue Karte erstellen
- `GET /api/cards/:cardId` - Einzelne Karte abrufen
- `PUT /api/cards/:cardId` - Karte aktualisieren
- `DELETE /api/cards/:cardId` - Karte löschen

### Wiederholungen (Reviews)

- `GET /api/boxes/:boxId/reviews/next` - Nächste fällige Karte(n) abrufen (`?limit=1`)
- `POST /api/cards/:cardId/review` - Review-Bewertung abgeben (`rating: "again" | "hard" | "good" | "easy"`)

### Statistiken

- `GET /api/boxes/:boxId/stats` - Statistiken einer Box (fällige Karten, nächste Fälligkeit, etc.)

### Import

- `POST /api/import/pdf` - PDF hochladen und Karten generieren (multipart/form-data)
- `POST /api/import/text` - Text verarbeiten und Karten generieren

---

## 🤖 OpenAI & PDF-Import

### Konfiguration

Setze die `OPENAI_API_KEY` in der `.env`-Datei des Backends.

### PDF-Import verwenden

**Mit cURL:**
```bash
curl -X POST http://localhost:3000/api/import/pdf \
  -H "Authorization: Bearer <token>" \
  -F "file=@document.pdf" \
  -F "boxId=<box-id>" \
  -F "sourceLanguage=German" \
  -F "targetLanguage=English" \
  -F "maxCards=20"
```

**Mit Postman:**
1. POST-Request an `/api/import/pdf`
2. Body-Type: `form-data`
3. Key `file`: Type `File`, wähle PDF
4. Key `boxId`: Text, Box-ID eingeben
5. Optional: `sourceLanguage`, `targetLanguage`, `maxCards`

### Text-Import verwenden

```bash
curl -X POST http://localhost:3000/api/import/text \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Dein Text hier...",
    "boxId": "<box-id>",
    "sourceLanguage": "German",
    "targetLanguage": "English",
    "maxCards": 20
  }'
```

Die OpenAI-Integration nutzt GPT-4, um aus Text/Vokabeln automatisch Karteikarten zu generieren. Die generierten Karten werden mit initialem FSRS-5-Status in der Datenbank gespeichert.

---

## 🔌 OpenAPI / Custom GPT Integration

Die vollständige OpenAPI-Spezifikation befindet sich in `backend/openapi.yaml`.

### In OpenAI Custom GPT einbinden

1. Öffne [OpenAI Custom GPT](https://chat.openai.com/gpts)
2. Erstelle einen neuen GPT oder bearbeite einen bestehenden
3. Gehe zu **Actions** → **Create new action**
4. Lade die `openapi.yaml` hoch oder füge die URL zur OpenAPI-Spezifikation ein
5. Konfiguriere die Authentifizierung:
   - Type: `HTTP Bearer`
   - Token: `<dein-jwt-token>` (oder lass den Nutzer sich anmelden)
6. Speichere und teste

Das Custom GPT kann nun:
- Boxen auflisten und erstellen
- Karten erstellen
- Karten aus PDFs/Text importieren
- Reviews auslösen

**Hinweis:** Für Produktion solltest du eine öffentlich erreichbare URL bereitstellen und ggf. API-Keys für das Custom GPT implementieren.

---

## 🧠 FSRS-5 Algorithmus

### Was ist FSRS-5?

**FSRS-5** (Free Spaced Repetition Scheduler v5) ist ein moderner Algorithmus zur optimalen Planung von Wiederholungen beim Lernen. Im Gegensatz zu einfachen Algorithmen wie SM-2 berücksichtigt FSRS-5:

- **Stability**: Wie stabil ist die Erinnerung? (in Tagen)
- **Difficulty**: Wie schwierig ist die Karte? (0-1)
- **Requested Retention**: Ziel-Erinnerungswahrscheinlichkeit (Standard: 90%)

### Wie funktioniert es in BrainFood?

1. **Neue Karte**: Erhält initiale Werte (Stability: 0.4 Tage, Difficulty: 0.3)
2. **Review-Bewertung**:
   - **Again**: Karte wurde vergessen → Stability sinkt stark, Lapse-Zähler erhöht
   - **Hard**: Schwierig erinnert → Stability wächst wenig
   - **Good**: Normal erinnert → Standardwachstum
   - **Easy**: Sehr einfach → Stability steigt stärker, längeres Intervall
3. **Nächstes Fälligkeitsdatum**: Wird basierend auf neuer Stability und Retention-Ziel berechnet

### Implementierung

Die FSRS-5-Logik befindet sich in:
- Backend: `backend/src/fsrs/fsrs.ts`
- Die Berechnungen werden serverseitig durchgeführt, um Konsistenz zu gewährleisten

---

## 🗄️ Datenbank-Schema

### User
- `id`, `name`, `email`, `passwordHash`, `createdAt`

### Box
- `id`, `userId`, `name`, `createdAt`

### Card
- `id`, `boxId`, `front`, `back`, `tags`
- FSRS-5: `stability`, `difficulty`, `reps`, `lapses`, `lastReviewAt`, `due`

### ReviewLog
- `id`, `cardId`, `userId`, `rating`, `reviewedAt`
- `previousStability`, `newStability`, `previousDue`, `newDue`, `interval`

---

## 🚢 Deployment (Ubuntu/Plesk)

### Backend auf Ubuntu-Server deployen

1. **Node.js installieren:**
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

2. **Projekt auf Server kopieren:**
   ```bash
   git clone <repository>
   cd BrainFood/backend
   npm install
   ```

3. **Umgebungsvariablen in Plesk setzen:**
   - Plesk → Domains → deine-domain.com → PHP Settings
   - Oder: Erstelle `.env`-Datei manuell

4. **Datenbank-Migrationen:**
   ```bash
   npm run migrate:deploy
   ```

5. **Server starten:**
   - Mit PM2 (empfohlen):
     ```bash
     npm install -g pm2
     pm2 start dist/index.js --name brainfood
     pm2 save
     ```
   - Oder als Systemd-Service
   - Oder über Plesk Node.js-App

6. **Reverse Proxy (Nginx/Apache):**
   - Konfiguriere Proxy-Pass auf `http://localhost:3000`
   - SSL-Zertifikat einrichten

### iOS-App für Produktion

1. Backend-URL in `APIClient.swift` auf Produktions-URL ändern
2. In Xcode: Product → Archive
3. App Store Connect hochladen oder Ad-Hoc-Distribution

---

## 🧪 Testing

### Backend-Tests

```bash
npm test
```

### API manuell testen

Nutze Tools wie:
- **Postman**
- **cURL**
- **httpie**
- **Insomnia**

Beispiel-Login:
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

---

## 📝 Entwicklung

### Backend

- **TypeScript** mit strikter Typisierung
- **Express** für HTTP-Server
- **Prisma** für Datenbankzugriff
- **JWT** für Authentifizierung

### iOS-App

- **SwiftUI** für UI
- **MVVM**-Architektur
- **URLSession** für Networking
- **Keychain** für sichere Token-Speicherung

---

## 🐛 Fehlerbehebung

### Backend startet nicht

- Prüfe, ob PostgreSQL läuft: `sudo systemctl status postgresql`
- Prüfe `.env`-Datei und `DATABASE_URL`
- Prüfe Port-Konflikte: `lsof -i :3000`

### iOS-App kann Backend nicht erreichen

- Prüfe Backend-URL in `APIClient.swift`
- Für physisches Gerät: Nutze IP-Adresse statt `localhost`
- Prüfe Firewall-Einstellungen
- Prüfe, ob Backend läuft: `curl http://localhost:3000/health`

### PDF-Import schlägt fehl

- Prüfe `OPENAI_API_KEY` in `.env`
- Prüfe API-Key-Gültigkeit und Credits
- Prüfe PDF-Größe (max. 10MB)
- Prüfe Server-Logs

---

## 📄 Lizenz

MIT License

---

## 🤝 Beitragen

Beiträge sind willkommen! Bitte erstelle einen Pull Request oder öffne ein Issue.

---

## 📧 Support

Bei Fragen oder Problemen öffne bitte ein Issue im Repository.

---

**Viel Erfolg beim Lernen mit BrainFood! 🧠📚**
