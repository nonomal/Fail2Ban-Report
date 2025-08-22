#!/bin/bash

set -euo pipefail

# === Configuration ===
LOGFILE="/var/log/fail2ban.log"                              # Pfad zum Fail2Ban Logfile
OUTPUT_JSON_DIR="/var/www/Fail2Ban-Report/archive"           # Lokaler Ordner (optional Archiv)
CLIENT_USER="meinclient"                                     # Client Benutzername
CLIENT_PASS="geheimespasswort"                               # Client Passwort
CLIENT_UUID="123e4567-e89b-12d3-a456-426614174000"           # UUID des Clients
ENDPOINT_URL="https://meinserver/Fail2Ban-Report/endpoint/"  # Server Endpoint-URL
CLIENT_LOG="/var/log/fail2ban-report-client.log"             # Logfile für den Client

# === Preparation ===
TODAY=$(date +"%Y-%m-%d")
TODAY_SHORT=$(date +"%Y%m%d")
OUTPUT_JSON_FILE="$OUTPUT_JSON_DIR/fail2ban-events-$TODAY_SHORT.json"
mkdir -p "$OUTPUT_JSON_DIR"

# === JSON Datei erzeugen ===
echo "[" > "$OUTPUT_JSON_FILE"

grep -E "(Ban|Unban)" "$LOGFILE" | awk -v today="$TODAY" '
{
    timestamp = $1 " " $2;
    if (index(timestamp, today) != 1) next;

    action = "";
    ip = "";
    if ($0 ~ /Increase Ban/) {
        action = "Increase Ban";
        match($0, /Increase Ban ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/, m);
        if (m[1]) ip = m[1];
    } else if ($0 ~ /Ban/) {
        action = "Ban";
        match($0, /Ban ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/, m);
        if (m[1]) ip = m[1];
    } else if ($0 ~ /Unban/) {
        action = "Unban";
        match($0, /Unban ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/, m);
        if (m[1]) ip = m[1];
    }

    text = $0;
    c = 0;
    delete arr;
    while (match(text, /\[[^]]+\]/)) {
        content = substr(text, RSTART+1, RLENGTH-2);
        c++;
        arr[c] = content;
        text = substr(text, RSTART + RLENGTH);
    }

    jail = "unknown";
    for(i=1; i<=c; i++) {
        if (arr[i] !~ /^[0-9]+$/) {
            jail = arr[i];
            break;
        }
    }

    if (ip != "") {
        printf "  {\n    \"timestamp\": \"%s\",\n    \"action\": \"%s\",\n    \"ip\": \"%s\",\n    \"jail\": \"%s\"\n  },\n", timestamp, action, ip, jail;
    }
}
' >> "$OUTPUT_JSON_FILE"

# Remove last comma
if [ -s "$OUTPUT_JSON_FILE" ]; then
    sed -i '$ s/},/}/' "$OUTPUT_JSON_FILE"
fi
echo "]" >> "$OUTPUT_JSON_FILE"

# === Datei an Server senden ===
HTTP_RESPONSE=$(curl -s -o /tmp/curl_response.txt -w "%{http_code}" \
  -F "username=$CLIENT_USER" \
  -F "password=$CLIENT_PASS" \
  -F "uuid=$CLIENT_UUID" \
  -F "file=@$OUTPUT_JSON_FILE" \
  "$ENDPOINT_URL")

SERVER_RESPONSE=$(cat /tmp/curl_response.txt)

# === Logging ===
if [ "$HTTP_RESPONSE" -eq 200 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') ✅ Upload success: $OUTPUT_JSON_FILE" >> "$CLIENT_LOG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ↩️  Server response: $SERVER_RESPONSE" >> "$CLIENT_LOG"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') ❌ Upload failed (HTTP $HTTP_RESPONSE)" >> "$CLIENT_LOG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ↩️  Server response: $SERVER_RESPONSE" >> "$CLIENT_LOG"
fi

# Cleanup
rm -f /tmp/curl_response.txt
