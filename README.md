# BrainFood

FSRS-gestützte Vokabel-App: iOS-Client (SwiftUI) plus Node/Express-Backend. Der FSRS-5 Plan sorgt dafür, dass Karten genau dann wiederholt werden, wenn die Erinnerungswahrscheinlichkeit auf das Ziel (requestRetention, hier 0.9) fällt.

## Projektstruktur
- `Backend/` – Express-Server mit FSRS-Scheduler, JSON-Storage, PDF-Import, OpenAI-Aktionsschema
- `Ios App/BrainFood/` – SwiftUI-App (Tab „Lernen“ und „Karten“) mit FSRS-Fallback für optimistische UI

## Backend (Ubuntu/Node)
1) Voraussetzungen: Node 18+, npm
2) Setup:
   ```bash
   cd Backend
   npm install
   npm start   # oder PORT=4000 npm start
   ```
3) API-Domain: `https://BrainFood.timrmp.de` (im iOS-Client hinterlegt). Für lokales Testing kannst du `APIService.shared.baseURL` zur Laufzeit anpassen, z. B. auf `http://localhost:3000`.
4) Kern-Endpunkte:
   - `GET /health` – Status + FSRS-Parameter
   - `GET /cards?dueOnly=true` – Alle Karten (optional nur fällige)
   - `POST /cards` – Neue Karte `{ front, back, tags? }`
   - `POST /cards/batch` – Mehrere Karten auf einmal `{ cards: [{front, back, tags?}] }`
   - `POST /review` – FSRS-Review `{ cardId, rating: 1..4 }` (1=Again, 2=Hard, 3=Good, 4=Easy)
   - `POST /import/pdf` – PDF hochladen (multipart Feld `file`, optional `delimiter`\nSeparator) -> erzeugt Karten aus Textzeilen
5) Datenhaltung: JSON-Datei `Backend/data/cards.json` (wird automatisch erstellt). Für größere Deployments ersetzbar durch DB; die Storage-Schicht sitzt in `Backend/storage.js`.
6) FSRS-Integration: `Backend/fsrs.js` implementiert die Kernmetriken Stability/Difficulty, Lapse-Handling, Intervalberechnung und nutzt Parameter, die nahe an FSRS-5 Defaults liegen. Anpassbar über `defaultConfig`.
7) OpenAI-Schema: `Backend/schema/openai-schema.json` beschreibt die API (OpenAPI 3.1). In deinem Custom GPT als Actions-Schema hinterlegen; GPT kann darüber Karten erstellen (`/cards`, `/cards/batch`) und Reviews anstoßen (`/review`).
8) Deployment-Hinweis: Auf Ubuntu z. B. per `pm2 start server.js --name brainfood` starten; Ports in Firewall freigeben (`ufw allow 3000/tcp`) oder Reverse-Proxy auf `https://BrainFood.timrmp.de` terminieren.

## iOS App (SwiftUI)
- Startscreen: Tab „Lernen“ (zeigt nächste fällige Karte, Antwort umdrehen, Buttons Again/Hard/Good/Easy) und „Karten“ (Liste, Suche, neue Karte anlegen).
- Networking: `APIService` (Basis-URL default `http://localhost:3000`). Für reales Gerät an lokale IP anpassen, z. B. `APIService.shared.baseURL = URL(string:"http://192.168.0.10:3000")!`.
- ViewModel: `AppViewModel` lädt Karten, schickt Reviews, nutzt FSRS-Fallback für optimistische UI während die Server-Antwort kommt.
- FSRS-Fallback: `FSRSCalculator` spiegelt die Backend-Logik grob und berechnet das nächste Intervall lokal, falls noch keine Server-Antwort da ist.

## FSRS 5 Kurzüberblick
- Jede Karte trägt `stability` (wie lange Wissen hält) und `difficulty` (wie schwer die Karte ist).
- Vor einem Review wird aus der vergangenen Zeit und Stability die Erinnerungswahrscheinlichkeit (Retrievability) geschätzt.
- Bewertet der/die Lernende:
  - `Again` (1): Stability wird stark reduziert, Difficulty steigt etwas, Lapse-Zähler hoch.
  - `Hard` (2) / `Good` (3): Stability wächst moderat; Difficulty passt sich etwas an.
  - `Easy` (4): Stability wächst stärker, nächstes Intervall wird länger.
- Das nächste Intervall = f(Stability, Ziel-Retention). Standard-Ziel: 90 % Erinnerungswahrscheinlichkeit (requestRetention = 0.9).

## Kunden-GPT / Karten aus PDFs
- Actions-Schema: `Backend/schema/openai-schema.json`
- Beispiel-Prompt für GPT: „Lies den folgenden Text und erstelle Karten im Format `{front, back, tags}`; nutze `/cards/batch`, rating 1..4 für Feedback.“
- PDF-Import: `POST /import/pdf` mit Multipart-Feld `file`. Option `delimiter` (default `\n`) legt fest, wie Textblöcke zu Karten geschnitten werden.

## Lokales Testing
- Backend: `npm start`, dann `curl http://localhost:3000/health`
- iOS: Xcode öffnen (`Ios App/BrainFood/BrainFood.xcodeproj`), Zielgerät wählen, starten. Bei echtem Gerät Basis-URL auf lokale IP setzen.

## Wartung / Erweiterungen
- FSRS-Parameter tunen: `Backend/fsrs.js` (`defaultConfig`) + ggf. SwiftUI-Fallback (`FSRSCalculator`).
- Persistenz austauschen: `storage.js` gegen DB-Adapter (z. B. SQLite oder Postgres) ersetzen.
- Authentifizierung ergänzen: Middleware vor `/cards` und `/review` schalten.
