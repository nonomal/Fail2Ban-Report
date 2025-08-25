#!/bin/bash
# Fail2Ban-Report-cronscript.sh

LOGFILE="/opt/Fail2Ban-Report/cronjobs.log"
echo "start" > $LOGFILE

# Run Information gathering
./fail2ban_log2json.sh > $LOGFILE
# wait 5 seconds
sleep 5

# Run downlod-checker to see if updates available
./download-checker.sh
DOWNLOAD_STATUS=$?
# if there are updates
if [ $DOWNLOAD_STATUS -eq 0 ]; then
    echo "✅ Found Updates, running sync cycle" > $LOGFILE
    ./firewall-update.sh > $LOGFILE
    ./syncback.sh > $LOGFILE
else
    echo "ℹ️ No Updates, no need to run firewall and syncback" > $LOGFILE
fi

echo "done" > $LOGFILE
