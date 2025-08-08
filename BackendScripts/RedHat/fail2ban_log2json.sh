#!/bin/bash

# === Configuration ===
LOGFILE="/var/log/fail2ban/fail2ban.log"        # Fail2Ban log path typical on RedHat systems
OUTPUT_JSON_DIR="/var/www/html/Fail2Ban/archive" # Typical web root on RedHat (Apache)

# === Preparation ===
TODAY=$(date +"%Y-%m-%d")                      # Current date "YYYY-MM-DD"
OUTPUT_JSON_FILE="$OUTPUT_JSON_DIR/fail2ban-events-$(date +"%Y%m%d").json"

mkdir -p "$OUTPUT_JSON_DIR"

# === Processing ===
echo "[" > "$OUTPUT_JSON_FILE"

grep -E "Ban |Unban " "$LOGFILE" | awk -v today="$TODAY" '
{
    # Typical RedHat log timestamp format: "Aug  8 22:56:10" (no year)
    # So we try to build a comparable string for filtering today

    months = "JanFebMarAprMayJunJulAugSepOctNovDec";
    month_num = index(months, substr($1,1,3)) / 3;
    day = $2;
    time = $3;

    # Build comparable string YYYY-MM-DD
    cmd = "date +\"%Y\"";
    cmd | getline year;
    close(cmd);

    # Format month and day with leading zeros if needed
    if (length(day) == 1) day = "0" day;

    timestamp = year "-" (month_num < 10 ? "0" month_num : month_num) "-" day " " time;

    # Only process entries from today
    if (timestamp !~ today) next;

    action = $(NF-1);
    ip = $NF;

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

    printf "  {\n    \"timestamp\": \"%s\",\n    \"action\": \"%s\",\n    \"ip\": \"%s\",\n    \"jail\": \"%s\"\n  },\n", timestamp, action, ip, jail;
}
' >> "$OUTPUT_JSON_FILE"

# Remove trailing comma if present
if [ -s "$OUTPUT_JSON_FILE" ]; then
    sed -i '$ s/},/}/' "$OUTPUT_JSON_FILE"
fi

echo "]" >> "$OUTPUT_JSON_FILE"

# === Final message ===
echo "✅ JSON created: $OUTPUT_JSON_FILE"
