#!/bin/bash
set -o pipefail

# ─── CONFIG ───────────────────────────────────────────────────────────────────
TOKEN="TU_TOKEN"
CHAT_ID="TU_CHAT_ID"
CHATWOOT_URL="https://tu-dominio.com"

RAM_THRESHOLD=85
CPU_THRESHOLD=90
DISK_THRESHOLD=90

EVOLUTION_URL="http://localhost:8080"
EVOLUTION_APIKEY="evolution_api_key"
EVOLUTION_INSTANCE="evolution_instance"
WHATSAPP_STACK_DIR="$HOME/whatsapp-stack"  ###el path que corresponda

# ─── ESTADO ───────────────────────────────────────────────────────────────────
RAM_STATE="/tmp/ram_alert"
CPU_STATE="/tmp/cpu_alert"
DISK_STATE="/tmp/disk_alert"
CHATWOOT_STATE="/tmp/chatwoot_alert"
CHATWOOT_COOLDOWN="/tmp/chatwoot_restart_cooldown"
WA_ALERT="/tmp/whatsapp_alert"
DOCKER_STATE="/tmp/docker_alert"
DOCKER_COOLDOWN="/tmp/docker_restart_cooldown"

# ─── TELEGRAM ─────────────────────────────────────────────────────────────────
send_msg() {
  curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="$1" >/dev/null
}

# ─── RAM ──────────────────────────────────────────────────────────────────────
RAM=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100}')
if [ "$RAM" -ge "$RAM_THRESHOLD" ]; then
  [ ! -f "$RAM_STATE" ] && send_msg "🚨 RAM ALTA: ${RAM}%" && touch "$RAM_STATE"
else
  [ -f "$RAM_STATE" ] && send_msg "✅ RAM normal (${RAM}%)" && rm -f "$RAM_STATE"
fi

# ─── CPU ──────────────────────────────────────────────────────────────────────
CPU=$(top -bn1 | grep "Cpu(s)" | sed 's/.*,\s*\([0-9.]*\)\s*id.*/\1/' | awk '{printf "%.0f", 100 - $1}')
if [ "$CPU" -ge "$CPU_THRESHOLD" ]; then
  [ ! -f "$CPU_STATE" ] && send_msg "🚨 CPU ALTA: ${CPU}%" && touch "$CPU_STATE"
else
  [ -f "$CPU_STATE" ] && send_msg "✅ CPU normal (${CPU}%)" && rm -f "$CPU_STATE"
fi

# ─── DISCO ────────────────────────────────────────────────────────────────────
DISK=$(df / | awk 'NR==2 {gsub("%",""); print $5}')
if [ "$DISK" -ge "$DISK_THRESHOLD" ]; then
  [ ! -f "$DISK_STATE" ] && send_msg "🚨 DISCO LLENO: ${DISK}%" && touch "$DISK_STATE"
else
  [ -f "$DISK_STATE" ] && send_msg "✅ DISCO OK (${DISK}%)" && rm -f "$DISK_STATE"
fi

# ─── CHATWOOT ─────────────────────────────────────────────────────────────────
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$CHATWOOT_URL")
if [ "$HTTP_CODE" != "200" ]; then
  if [ ! -f "$CHATWOOT_STATE" ]; then
    if [ ! -f "$CHATWOOT_COOLDOWN" ]; then
      send_msg "🚨 Chatwoot CAIDO — reiniciando..."
      docker restart chatwoot 2>/dev/null || systemctl restart chatwoot 2>/dev/null
      touch "$CHATWOOT_COOLDOWN"
      (sleep 1800 && rm -f "$CHATWOOT_COOLDOWN") &
      sleep 30
      HTTP_CODE2=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$CHATWOOT_URL")
      if [ "$HTTP_CODE2" = "200" ]; then
        send_msg "🟢 Chatwoot RECUPERADO automaticamente"
      else
        send_msg "❌ Chatwoot sigue caido — revision manual requerida"
        touch "$CHATWOOT_STATE"
      fi
    else
      send_msg "⚠️ Chatwoot sigue caido (restart en cooldown, sin reintentar)"
    fi
  fi
else
  [ -f "$CHATWOOT_STATE" ] && send_msg "✅ Chatwoot RECUPERADO" && rm -f "$CHATWOOT_STATE"
fi

# ─── WHATSAPP (Evolution API) ─────────────────────────────────────────────────
WA_RESPONSE=$(curl -s --max-time 10 \
  "${EVOLUTION_URL}/instance/connectionState/${EVOLUTION_INSTANCE}" \
  -H "apikey: ${EVOLUTION_APIKEY}" 2>/dev/null)

WA_STATE_VAL=$(echo "$WA_RESPONSE" | jq -r '.instance.state // "error"' 2>/dev/null || echo "error")

if [ "$WA_STATE_VAL" = "error" ] || [ -z "$WA_STATE_VAL" ]; then
  if [ ! -f "$WA_ALERT" ]; then
    send_msg "🚨 Evolution API no responde — verificar contenedor"
    touch "$WA_ALERT"
  fi
elif [ "$WA_STATE_VAL" != "open" ]; then
  if [ ! -f "$WA_ALERT" ]; then
    send_msg "🚨 WhatsApp DESCONECTADO
Instancia: ${EVOLUTION_INSTANCE}
Estado: ${WA_STATE_VAL}
Accion: reconectar desde el panel de Evolution"
    touch "$WA_ALERT"
  fi
else
  [ -f "$WA_ALERT" ] && send_msg "✅ WhatsApp RECONECTADO (${EVOLUTION_INSTANCE})" && rm -f "$WA_ALERT"
fi

# ─── DOCKER STACK ─────────────────────────────────────────────────────────────
if [ -d "$WHATSAPP_STACK_DIR" ]; then
  cd "$WHATSAPP_STACK_DIR" || exit 1

  DEAD=$(docker compose ps --format json 2>/dev/null \
    | jq -r 'if type == "array" then .[] else . end
             | select(.State != "running" and .State != "healthy")
             | .Name' 2>/dev/null)

  if [ -n "$DEAD" ]; then
    if [ ! -f "$DOCKER_STATE" ]; then
      DEAD_LIST=$(echo "$DEAD" | tr '\n' ', ' | sed 's/,$//')
      if [ ! -f "$DOCKER_COOLDOWN" ]; then
        send_msg "🚨 Contenedores caidos en whatsapp-stack:
${DEAD_LIST}
Intentando levantar..."
        docker compose up -d 2>/dev/null
        touch "$DOCKER_COOLDOWN"
        (sleep 1800 && rm -f "$DOCKER_COOLDOWN") &
        sleep 20
        DEAD2=$(docker compose ps --format json 2>/dev/null \
          | jq -r 'if type == "array" then .[] else . end
                   | select(.State != "running" and .State != "healthy")
                   | .Name' 2>/dev/null)
        if [ -z "$DEAD2" ]; then
          send_msg "🟢 Stack RECUPERADO automaticamente"
        else
          DEAD2_LIST=$(echo "$DEAD2" | tr '\n' ', ' | sed 's/,$//')
          send_msg "❌ Stack sigue con problemas: ${DEAD2_LIST}"
          touch "$DOCKER_STATE"
        fi
      else
        send_msg "⚠️ Contenedores caidos: ${DEAD_LIST} (restart en cooldown)"
      fi
    fi
  else
    [ -f "$DOCKER_STATE" ] && send_msg "✅ Docker stack OK" && rm -f "$DOCKER_STATE"
  fi
fi
