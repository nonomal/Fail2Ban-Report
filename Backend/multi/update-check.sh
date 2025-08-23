#!/bin/bash

# ------------------------------
# Konfiguration
# ------------------------------
SERVER_URL="https://deinserver.tld/Fail2Ban-Report/endpoint/update.php"
USERNAME="alice"             # Dein Username auf dem Server
PASSWORD="dein_passwort"     # Passwort für Authentifizierung
UUID="123e4567-e89b-12d3-a456-426614174000"  # UUID des Clients
TARGET_DIR="/var/lib/blocklists"  # Zielverzeichnis für die Blocklists
LOGFILE="/var/log/blocklist_update.log"     # Logfile für Debug und Status

# ------------------------------
# Hilfsfunktion für Logging
# ------------------------------
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

# ------------------------------
# JSON-Request an den Server
# ------------------------------
log "Prüfe auf Updates für $USERNAME ..."

RESPONSE=$(curl -s -X POST "$SERVER_URL" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\", \"password\":\"$PASSWORD\", \"uuid\":\"$UUID\"}")

# Rohantwort loggen
log "RAW RESPONSE: $RESPONSE"

# ------------------------------
# Prüfen ob der Request erfolgreich war
# ------------------------------
SUCCESS=$(echo "$RESPONSE" | jq -r '.success')

if [ "$SUCCESS" != "true" ]; then
    ERROR=$(echo "$RESPONSE" | jq -r '.error // "Unbekannter Fehler"')
    log "Fehler beim Abrufen: $ERROR"
    exit 1
fi

# ------------------------------
# Blocklists extrahieren und speichern
# ------------------------------
UPDATES=$(echo "$RESPONSE" | jq -r '.updates | keys[]?')

if [ -z "$UPDATES" ]; then
    log "Keine Updates verfügbar."
    exit 0
fi

mkdir -p "$TARGET_DIR"

for BLOCKLIST in $UPDATES; do
    log "Lade Blocklist $BLOCKLIST ..."
    CONTENT=$(echo "$RESPONSE" | jq -c ".updates[\"$BLOCKLIST\"]")
    echo "$CONTENT" > "$TARGET_DIR/$BLOCKLIST"
done

log "Updates erfolgreich heruntergeladen."
