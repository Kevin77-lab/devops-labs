update+telegram
#!/bin/bash

TOKEN="your_token"
CHAT_ID="your_chatid"

send_msg() {
  curl --max-time 15 -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$1"
}

LOG="/home/deploy/scripts/update.log"

echo "===== $(date) =====" >> "$LOG"

apt update >> "$LOG" 2>&1
apt upgrade -y >> "$LOG" 2>&1

STATUS=$?

if [ $STATUS -eq 0 ]; then
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="✅ VPS $(hostname) actualizado correctamente"
else
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="❌ ERROR actualizando VPS $(hostname)"
fi

if [ -f /var/run/reboot-required ]; then
    send_msg "🔁 VPS $(hostname): reinicio necesario"
fi