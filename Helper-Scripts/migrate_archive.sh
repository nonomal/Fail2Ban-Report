#!/bin/bash
# migrate_archive.sh
# Script to reorganize archive JSON files into new structure

# Konfiguration
ARCHIVE="./archive"
SERVER_NAME="$1"  # Hostname als Parameter übergeben
WEB_USER="www-data"
WEB_GROUP="www-data"

if [ -z "$SERVER_NAME" ]; then
    echo "Usage: $0 <server_name>"
    exit 1
fi

# Zielordner erstellen
TARGET_DIR="$ARCHIVE/$SERVER_NAME"
mkdir -p "$TARGET_DIR/fail2ban" "$TARGET_DIR/blocklists" "$TARGET_DIR/ufw"

# Move fail2ban files
if compgen -G "$ARCHIVE/fail2ban-events*.json" > /dev/null; then
    mv "$ARCHIVE"/fail2ban-events*.json "$TARGET_DIR/fail2ban/"
fi

# Move blocklist files
if compgen -G "$ARCHIVE/*.blocklist.json" > /dev/null; then
    mv "$ARCHIVE"/*.blocklist.json "$TARGET_DIR/blocklists/"
fi

# Move ufw files
if compgen -G "$ARCHIVE/ufw*.json" > /dev/null; then
    mv "$ARCHIVE"/ufw*.json "$TARGET_DIR/ufw/"
fi

# Rechte setzen
chown -R "$WEB_USER":"$WEB_GROUP" "$TARGET_DIR"
chmod -R 640 "$TARGET_DIR"  # Lese-/Schreibrechte für User, lesen für Gruppe

echo "Migration completed successfully for server: $SERVER_NAME"
