#!/bin/bash

# Pfad als Variable festlegen
BASE_PATH="$1"

# Prüfen, ob ein Pfad übergeben wurde
if [ -z "$BASE_PATH" ]; then
    echo "Bitte einen Pfad als Parameter angeben."
    exit 1
fi

# Prüfen, ob der Pfad existiert
if [ ! -d "$BASE_PATH" ]; then
    echo "Der angegebene Pfad existiert nicht."
    exit 1
fi

# Für jeden Ordner im angegebenen Pfad
for DIR in "$BASE_PATH"/*/; do
    # Prüfen, ob es einen Ordner "fail2ban" gibt
    if [ -d "${DIR}fail2ban" ]; then
        echo "Bearbeite Ordner: ${DIR}fail2ban"
        
        # Unterordner erstellen, falls nicht vorhanden
        mkdir -p "${DIR}fail2ban/blocklists"
        mkdir -p "${DIR}fail2ban/ufw"
        mkdir -p "${DIR}fail2ban/stats"
    fi
done

echo "Fertig!"
