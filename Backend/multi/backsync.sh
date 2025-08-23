#!/bin/bash
# firewall-update.sh – Wendet Blocklist auf Firewall an und synchronisiert anschließend

set -euo pipefail

# === Konfiguration ===
BACKSYNC_URL="https://my.server.tld/Fail2Ban-Report/endpoint/backsync.php"
CLIENT_USER="MyClientName"
CLIENT_PASS="MyPassword"
CLIENT_UUID="MyUUID"
BLOCKLIST_DIR="/var/lib/fail2ban-report/blocklists"
LOG_FILE="/var/log/fail2ban-report-firewall.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

# === 1) Firewall aktualisieren (hier Beispiel mit iptables) ===
for file in "$BLOCKLIST_DIR"/*.json; do
    [[ -f "$file" ]] || continue
    for ip in $(jq -r '.[].ip' "$file"); do
        # Beispiel: IP blockieren
        iptables -I INPUT -s "$ip" -j DROP || true
    done
done
log "✅ Firewall-Update abgeschlossen."

# === 2) Blocklists zurück an Server synchronisieren ===
for file in "$BLOCKLIST_DIR"/*.json; do
    [[ -f "$file" ]] || continue
    log "🔄 Upload von $(basename "$file") zum Server..."
    response=$(curl -s -w "\n%{http_code}" -X POST "$BACKSYNC_URL" \
        -F "username=$CLIENT_USER" \
        -F "password=$CLIENT_PASS" \
        -F "uuid=$CLIENT_UUID" \
        -F "file=@$file" || true)
    
    http_code=$(tail -n1 <<< "$response")
    body=$(sed '$d' <<< "$response")

    if [[ "$http_code" -ne 200 ]]; then
        log "❌ Upload fehlgeschlagen: HTTP $http_code, Response: $body"
    else
        log "✅ Upload erfolgreich: $(basename "$file")"
        # Optional lokale Datei löschen
        rm -f "$file"
    fi
done

log "🔄 Backsync abgeschlossen."
