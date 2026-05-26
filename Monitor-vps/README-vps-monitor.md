# vps-monitor.sh

Script de monitoreo en tiempo real para un VPS. Verifica RAM, CPU, disco, disponibilidad HTTP de Chatwoot, estado de WhatsApp vía Evolution API y contenedores Docker. Envía alertas y recuperaciones por Telegram con sistema de estado para evitar spam.

Probado en **Ubuntu 24.04 LTS** sobre Hetzner.

---

## Qué monitorea

| Recurso                    | Alerta cuando         |   Recuperación         |
|----------------------------|-----------------------|------------------------|
| RAM                        |     ≥ 85%             | Notifica al bajar      |
| CPU                        |     ≥ 90%             | Notifica al bajar      |
| Disco                      |     ≥ 90%             | Notifica al bajar      |
| Chatwoot HTTP              |     HTTP ≠ 200        | Notifica al recuperar  |
| WhatsApp (Evolution API)   | Estado ≠ `open`       | Notifica al reconectar |
| Docker Stack               | Contenedor caído      | Notifica al recuperar  |

> Las alertas se envían **una sola vez** por evento. No spamea si el problema persiste.

---

## Requisitos

- VPS con Ubuntu/Debian
- Docker y Docker Compose
- `jq` instalado (`apt install jq`)
- Evolution API corriendo localmente
- Bot de Telegram configurado (ver abajo)

---

## Configurar el bot de Telegram

1. Abrí Telegram y buscá **@BotFather**
2. Ejecutá `/newbot` y seguí los pasos para elegir nombre y username
3. BotFather te devuelve un token: `123456789:AAExampleTokenHere`
4. Mandále un mensaje al bot (ej: "hola")
5. Abrí en el navegador:
   ```
   https://api.telegram.org/botTU_TOKEN/getUpdates
   ```
6. Buscá `"chat":{"id":123456789}` — ese número es tu `CHAT_ID`

### Para usarlo en un grupo

- En BotFather, habilitá la opción de escuchar mensajes en grupos (Privacy Mode → off)
- Agregá el bot al grupo
- Repetí los pasos 4–6 mandando el mensaje al grupo en vez de al bot directamente

---

## Instalación

Hacé el script ejecutable:

```bash
chmod +x vps-monitor.sh
```

Editá las variables de configuración al inicio del script:

```bash
TOKEN="tu_token_aqui"
CHAT_ID="tu_chat_id_aqui"
CHATWOOT_URL="https://tu-dominio.com/"
EVOLUTION_URL="http://localhost:8080"
EVOLUTION_APIKEY="tu_apikey"
EVOLUTION_INSTANCE="nombre-instancia"
WHATSAPP_STACK_DIR="/ruta/a/tu/docker-compose"
```

También podés ajustar los umbrales:

```bash
RAM_THRESHOLD=85
CPU_THRESHOLD=90
DISK_THRESHOLD=90
```

---

## Uso

### Ejecución manual

```bash
./vps-monitor.sh


### Automatizar con cron

```bash
sudo crontab -e
```

Agregá esta línea para ejecutarlo cada 5 minutos:

```
*/5 * * * * /root/vps-monitor.sh
```

Los logs se guardan en `/var/log/monitor.log`.

---

## Notificaciones

| Evento                | Mensaje                         |
|-----------------------|--------------------------------|
| RAM alta              | 🚨 RAM ALTA: 87%               |
| RAM recuperada        | ✅ RAM normal (74%)            |
| CPU alta              | 🚨 CPU ALTA: 92%               |
| CPU recuperada        | ✅ CPU normal (45%)            |
| Disco lleno           | 🚨 DISCO LLENO: 91%            |
| Disco OK              | ✅ DISCO OK (78%)              |
| Chatwoot caído        | 🚨 Chatwoot CAIDO (HTTP 502)   |
| Chatwoot OK           | ✅ Chatwoot OK                 |
| WhatsApp desconectado | 🚨 WhatsApp DESCONECTADO       |
| WhatsApp reconectado  | ✅ WhatsApp reconectado        |
| Contenedor caído      | 🚨 Contenedores caidos: nombre |
| Docker stack OK       | ✅ Docker stack OK             |
