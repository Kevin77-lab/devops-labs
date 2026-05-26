# update-monitor.sh

Script de automatización para actualizar un VPS y recibir notificaciones por Telegram.

Probado en **Ubuntu 24.04 LTS** sobre Hetzner. Notifica si la actualización fue exitosa o falló, y si el sistema requiere reinicio. El reinicio no se automatiza para evitar interrumpir servicios en producción.

---

## Requisitos

- VPS con Ubuntu/Debian
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

Cloná o copiá el script y hacelo ejecutable:

```bash
chmod +x update-monitor.sh
```

Editá las variables al inicio del script:

```bash
TOKEN="tu_token_aqui"
CHAT_ID="tu_chat_id_aqui"
```

---

## Uso

### Ejecución manual

```bash
./update-monitor.sh
```

### Automatizar con cron

```bash
sudo crontab -e
```

Agregá esta línea para ejecutarlo todos los días a las 3 AM:

```
0 3 * * * /root/update-monitor.sh
```

> Las 3 AM suele ser el horario de menor actividad en servidores.

---

## Notificaciones

| Evento | Mensaje |
|---|---|
| Actualización exitosa | ✅ VPS hostname actualizado correctamente |
| Error en la actualización | ❌ ERROR actualizando VPS hostname |
| Reinicio requerido | 🔁 VPS hostname: reinicio necesario |
