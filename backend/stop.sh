#!/bin/bash

# BrainFood Backend Stop Script
# Stoppt alle Node.js-Prozesse, die auf Port 3000 laufen

PORT=${1:-3000}

echo "Suche nach Prozessen auf Port $PORT..."

# Finde Prozess-ID auf dem Port
PID=$(lsof -t -i:$PORT 2>/dev/null)

if [ -z "$PID" ]; then
    echo "Kein Prozess auf Port $PORT gefunden."
    exit 0
fi

echo "Prozess gefunden: PID $PID"
echo "Stoppe Prozess..."

# Beende den Prozess
kill $PID 2>/dev/null

# Warte kurz
sleep 1

# Prüfe ob Prozess noch läuft
if ps -p $PID > /dev/null 2>&1; then
    echo "Prozess läuft noch, erzwinge Beendigung..."
    kill -9 $PID 2>/dev/null
fi

echo "Prozess gestoppt."

