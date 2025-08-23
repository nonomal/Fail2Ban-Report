#!/bin/bash

# --- Configuration ---
ENDPOINT_URL="https://SERVERURL/Fail2Ban-Report/endpoint/update.php"
USERNAME="SERVERNAME"
PASSWORD="PASSWORD"
UUID="UUID"

# --- Anfrage an update.php ---
response=$(curl -s -X POST "$ENDPOINT_URL" \
  -F "username=$USERNAME" \
  -F "password=$PASSWORD" \
  -F "uuid=$UUID")

# Ausgabe der Server-Antwort
echo "Server Response:"
echo "$response"

# --- Optionale Überprüfung, ob Updates vorhanden sind ---
updates=$(echo "$response" | jq -r '.updates | length')
if [ "$updates" -gt 0 ]; then
  echo "✅ Updates available: $updates blocklist(s)."
else
  echo "ℹ️ No updates available."
fi
