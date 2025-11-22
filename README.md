# BrainFood - Vokabel-App mit FSRS-5

BrainFood ist eine moderne iOS-Vokabel-App, die den **FSRS-5 Algorithmus** für intelligente Wiederholungsplanung nutzt. Die App ermöglicht effizientes Lernen von Vokabeln über Boxen und Karteikarten, unterstützt PDF-Import mit OpenAI-gestützter Kartenerstellung und bietet eine vollständige Backend-API.

## 📚 Projektübersicht

### Was ist BrainFood?

BrainFood ist eine Karteikarten-App für iOS, die:
- **FSRS-5 Spaced Repetition** zur optimalen Lernplanung nutzt
- Vokabeln in **Boxen** organisiert
- **PDF-Import** mit automatischer Kartenerstellung via OpenAI unterstützt
- Eine **REST-API** für Backend-Server bietet
- **OpenAPI-Schema** für Custom GPT Integration bereitstellt

### Was ist FSRS-5?

**FSRS-5** (Free Spaced Repetition Scheduler) ist ein fortschrittlicher Algorithmus zur Planung von Wiederholungen basierend auf der Vergessenskurve. Im Gegensatz zu einfachen Algorithmen wie SM-2 berücksichtigt FSRS-5:

- **Stabilität** des Gedächtnisses (wie lange eine Information im Gedächtnis bleibt)
- **Schwierigkeit** der Karte (wie schwer es ist, sich an die Information zu erinnern)
- **Optimale Intervalle** für Wiederholungen, um eine Erinnerungswahrscheinlichkeit von ~90% zu erreichen

Der Algorithmus passt sich dynamisch an dein Lernverhalten an und optimiert die Wiederholungsintervalle für maximale Effizienz.

## 🏗️ Projektstruktur

```
BrainFood/
├── backend/              # Node.js/TypeScript Backend-Server
│   ├── src/
│   │   ├── fsrs/         # FSRS-5 Algorithmus Implementation
│   │   ├── routes/       # REST-API Endpunkte
│   │   ├── services/     # OpenAI, PDF-Services
│   │   ├── middleware/   # Auth-Middleware
│   │   └── utils/        # JWT, Password-Hashing
│   ├── prisma/           # Datenbank-Schema
│   └── openapi.yaml      # OpenAPI-Spezifikation
│
└── ios-app/              # iOS-App (SwiftUI)
    └── BrainFood/
        ├── Models/       # Datenmodelle
        ├── Services/     # API-Client, Keychain
        ├── ViewModels/   # MVVM ViewModels
        └── Views/        # SwiftUI Views
```

## 🚀 Setup & Installation

### Voraussetzungen

#### Backend
- **Node.js** 18+ und npm
- **PostgreSQL** 14+ (für Produktion) oder SQLite (für lokale Entwicklung)
- **OpenAI API Key** (für PDF-Import)

#### iOS-App
- **Xcode** 15+ mit iOS 17 SDK
- **macOS** für Entwicklung

---

## 📦 Backend Setup

### 1. Abhängigkeiten installieren

```bash
cd backend
npm install
```

### 2. Umgebungsvariablen konfigurieren

Erstelle eine `.env` Datei im `backend/` Verzeichnis:

```env
# Datenbank
DATABASE_URL="postgresql://user:password@localhost:5432/brainfood?schema=public"

# JWT
JWT_SECRET="your-super-secret-jwt-key-change-this-in-production"
JWT_EXPIRES_IN="12h"

# OpenAI
OPENAI_API_KEY="your-openai-api-key-here"

# Server
PORT=3000
NODE_ENV=development
```

**Wichtig:** 
- Ersetze `DATABASE_URL` mit deinen PostgreSQL-Credentials
- Generiere einen sicheren `JWT_SECRET` (z.B. mit `openssl rand -base64 32`)
- Füge deinen OpenAI API Key hinzu

### 3. Datenbank-Migrationen ausführen

```bash
# Prisma Client generieren
npm run generate

# Datenbank-Migrationen ausführen
npm run migrate
```

### 4. Server starten

**Entwicklung:**
```bash
npm run dev
```

**Produktion:**
```bash
npm run build
npm run start
```

Der Server läuft dann auf `http://localhost:3000` (oder dem in `PORT` definierten Port).

### 5. Deployment auf Ubuntu/Plesk

#### Voraussetzungen auf dem Server:
- Node.js 18+ installiert
- PostgreSQL-Datenbank erstellt
- Plesk mit Node.js-Support

#### Schritte:

1. **Projekt auf Server hochladen** (z.B. via Git, FTP, oder Plesk File Manager)

2. **Node.js-Version in Plesk konfigurieren:**
   - In Plesk: Domain → Node.js
   - Node.js-Version auswählen (18+)
   - Document Root auf `/backend` setzen
   - Application Startup File: `dist/index.js`

3. **Umgebungsvariablen in Plesk setzen:**
   - In Plesk: Domain → Node.js → Environment Variables
   - Alle Variablen aus `.env` hinzufügen:
     - `DATABASE_URL`
     - `JWT_SECRET`
     - `OPENAI_API_KEY`
     - `PORT` (optional, Standard: 3000)
     - `NODE_ENV=production`

4. **Dependencies installieren:**
   ```bash
   cd backend
   npm install --production
   ```

5. **Datenbank-Migrationen:**
   ```bash
   npm run generate
   npm run migrate:deploy
   ```

6. **App starten:**
   - In Plesk: Node.js → "Enable Node.js" aktivieren
   - Oder manuell: `npm run start`

7. **Reverse Proxy konfigurieren** (optional, für HTTPS):
   - In Plesk: Domain → Apache & nginx Settings
   - Reverse Proxy zu `http://localhost:3000` einrichten

---

## 📱 iOS-App Setup

### 1. Xcode-Projekt öffnen

```bash
cd "IOS App/BrainFood"
open BrainFood.xcodeproj
```

### 2. Backend-URL konfigurieren

Öffne `ios-app/BrainFood/Services/APIClient.swift` und passe die `baseURL` an:

```swift
private let baseURL = "http://localhost:3000/api"  // Lokal
// oder
private let baseURL = "https://your-domain.com/api"  // Produktion
```

### 3. App bauen und ausführen

- Wähle ein iOS-Simulator oder Gerät in Xcode
- Drücke `Cmd + R` zum Builden und Ausführen

**Hinweis:** Für Tests auf einem physischen Gerät muss das Backend über das lokale Netzwerk erreichbar sein (z.B. `http://192.168.1.100:3000/api`).

---

## 🔑 API-Endpunkte

### Authentifizierung

- `POST /api/auth/register` - Neuen Benutzer registrieren
- `POST /api/auth/login` - Benutzer anmelden
- `GET /api/auth/me` - Aktuellen Benutzer abrufen
- `POST /api/auth/logout` - Abmelden

### Boxen

- `GET /api/boxes` - Alle Boxen abrufen
- `POST /api/boxes` - Neue Box erstellen
- `PUT /api/boxes/:boxId` - Box aktualisieren
- `DELETE /api/boxes/:boxId` - Box löschen

### Karten

- `GET /api/boxes/:boxId/cards` - Alle Karten einer Box abrufen
- `POST /api/boxes/:boxId/cards` - Neue Karte erstellen
- `GET /api/cards/:cardId` - Karten-Details abrufen
- `PUT /api/cards/:cardId` - Karte aktualisieren
- `DELETE /api/cards/:cardId` - Karte löschen

### Wiederholungen (Reviews)

- `GET /api/boxes/:boxId/reviews/next` - Nächste fällige Karte(n) abrufen
- `POST /api/cards/:cardId/review` - Review-Bewertung abgeben (again/hard/good/easy)

### Statistiken

- `GET /api/boxes/:boxId/stats` - Statistiken für eine Box abrufen

### Import

- `POST /api/import/pdf` - Karten aus PDF importieren (multipart/form-data)
- `POST /api/import/text` - Karten aus Text importieren

**Detaillierte API-Dokumentation:** Siehe `backend/openapi.yaml`

---

## 🤖 OpenAI & PDF-Import

### OpenAI API Key konfigurieren

1. Erstelle einen OpenAI API Key auf [platform.openai.com](https://platform.openai.com)
2. Füge den Key in die `.env` Datei ein:
   ```env
   OPENAI_API_KEY="sk-..."
   ```

### PDF-Import testen

**Mit cURL:**
```bash
curl -X POST http://localhost:3000/api/import/pdf \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "file=@/path/to/document.pdf" \
  -F "boxId=YOUR_BOX_ID" \
  -F "sourceLanguage=Deutsch" \
  -F "targetLanguage=Englisch"
```

**Mit Postman:**
1. POST Request an `/api/import/pdf`
2. Header: `Authorization: Bearer YOUR_TOKEN`
3. Body: `form-data`
   - `file`: PDF-Datei auswählen
   - `boxId`: Box-ID eingeben
   - `sourceLanguage`: (optional) z.B. "Deutsch"
   - `targetLanguage`: (optional) z.B. "Englisch"

### Wie funktioniert der Import?

1. **PDF wird hochgeladen** → Text wird extrahiert
2. **Text wird in Chunks aufgeteilt** (max. 3000 Zeichen pro Chunk)
3. **OpenAI generiert Karteikarten** aus jedem Chunk
4. **Karten werden in der Datenbank gespeichert** mit initialem FSRS-5 State

---

## 🧠 OpenAPI / Custom GPT Integration

### OpenAPI-Schema

Das vollständige OpenAPI-Schema befindet sich in `backend/openapi.yaml`.

### Custom GPT einrichten

1. **OpenAI Custom GPT erstellen:**
   - Gehe zu [chat.openai.com/gpts](https://chat.openai.com/gpts)
   - Erstelle ein neues Custom GPT

2. **Action hinzufügen:**
   - In den GPT-Einstellungen: "Actions" → "Create new action"
   - Import: Lade `backend/openapi.yaml` hoch
   - Oder kopiere den Inhalt der YAML-Datei

3. **Authentifizierung konfigurieren:**
   - Type: "HTTP Bearer"
   - Token: Dein JWT-Token (kann auch dynamisch über Login-Endpoint geholt werden)

4. **Verwendung:**
   - Das Custom GPT kann nun:
     - Boxen auflisten und erstellen
     - Karten erstellen
     - Karten aus PDFs importieren
     - Reviews auslösen

**Beispiel-Prompts für Custom GPT:**
- "Erstelle eine neue Box namens 'Spanisch Vokabeln'"
- "Importiere Karten aus diesem PDF: [PDF hochladen]"
- "Zeige mir alle Boxen"
- "Erstelle eine Karte mit Front 'Hola' und Back 'Hallo'"

---

## 📊 FSRS-5 Algorithmus

### Wie funktioniert FSRS-5 in BrainFood?

Der FSRS-5 Algorithmus wird im Backend implementiert (`backend/src/fsrs/`) und berechnet für jede Karte:

1. **Stabilität (Stability):** Wie lange die Information im Gedächtnis bleibt
2. **Schwierigkeit (Difficulty):** Wie schwer es ist, sich an die Information zu erinnern (0-1)
3. **Nächstes Fälligkeitsdatum (Due):** Wann die Karte wiederholt werden sollte

### Bewertungen

- **Again (Rot):** Karte nicht gewusst → Stabilität stark reduziert, sehr kurzes Intervall (1 Tag)
- **Hard (Orange):** Schwierig gewusst → Stabilität wächst wenig, kürzeres Intervall
- **Good (Grün):** Normal gewusst → Standard-Wachstum, normales Intervall
- **Easy (Blau):** Leicht gewusst → Größeres Intervall, stärkeres Wachstum

### Ziel

Das Ziel ist eine **Erinnerungswahrscheinlichkeit von ~90%** bei jeder Wiederholung, um optimales Lernen zu gewährleisten.

### Implementierung

Die FSRS-5 Logik befindet sich in:
- `backend/src/fsrs/types.ts` - Typen und Parameter
- `backend/src/fsrs/fsrs.ts` - Algorithmus-Implementation

---

## 🧪 Testing

### Backend-Tests

```bash
cd backend
npm test  # (wenn Tests implementiert sind)
```

### API testen

**Health Check:**
```bash
curl http://localhost:3000/health
```

**Login:**
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

---

## 🐛 Fehlerbehebung

### Backend startet nicht

- Prüfe, ob PostgreSQL läuft und die `DATABASE_URL` korrekt ist
- Führe `npm run generate` aus, um Prisma Client zu generieren
- Prüfe die `.env` Datei auf korrekte Werte

### iOS-App kann Backend nicht erreichen

- Prüfe die `baseURL` in `APIClient.swift`
- Für physische Geräte: Backend muss über lokales Netzwerk erreichbar sein
- Prüfe Firewall-Einstellungen

### PDF-Import schlägt fehl

- Prüfe, ob `OPENAI_API_KEY` gesetzt ist
- Prüfe OpenAI API Limits und Credits
- PDF-Datei sollte nicht größer als 10 MB sein

---

## 📝 Lizenz

MIT License

---

## 🤝 Beitragen

Beiträge sind willkommen! Bitte erstelle einen Pull Request oder öffne ein Issue.

---

## 📞 Support

Bei Fragen oder Problemen:
- Öffne ein Issue im Repository
- Prüfe die API-Dokumentation in `backend/openapi.yaml`

---

**Viel Erfolg beim Lernen mit BrainFood! 🧠📚**
