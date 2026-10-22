# PSR3 protocol draft

## Network

Default PSR3 Wi-Fi: `PSR3`

Default console address:

`192.168.4.1`

The Windows app stores only the base IP. It appends API paths itself.

## Browser root

Opening `http://192.168.4.1/` in a browser should display a plain black page.

The root page is not the PSR3 control panel. Application functions live under `/api/...`.

## API

### Status

`GET /api/status`

Planned JSON:

```json
{
  "firmware": "0.2.0",
  "mode": "on",
  "error": "",
  "free_heap": 0,
  "largest_block": 0,
  "wifi_rssi": -50
}
```

Supported `mode` values:

- `on`
- `standby`
- `safe`
- `update`

When `mode` is `safe`, the Windows app disables Settings and Remote Play. Direct Connection remains available and shows connection data, free memory, the current error, Restart and Update.

### Remote Play pairing

`POST /api/remote/pair`

Request:

```json
{
  "code": "1234"
}
```

A 2xx response means that the code shown on the TV was accepted.

Remote Play must reject pairing while the console reports `mode: safe`.

### Restart

`POST /api/restart`

### Power mode

Turn the console on:

`POST /api/power/on`

Put the console into standby:

`POST /api/power/standby`

### Update Mode

First switch the console to Update Mode:

`POST /api/update-mode`

After the user selects a firmware file, the Windows app uploads it with:

`POST /api/update/firmware`

Request body:

- Content-Type: `application/octet-stream`
- `X-Filename` header: selected firmware file name
- body: raw firmware bytes

A 2xx response means the file was accepted by the console. The console firmware is responsible for validating the image before flashing it.

## Remote Play transport

The current Windows Remote Play screen provides the connection/pairing flow and UI. A future renderer/stream can use a WebSocket such as:

`ws://192.168.4.1/ws/stream`

The exact stream format remains open until the console-side renderer is implemented.

## Recovery

Recovery remains on the console itself and is displayed on the TV over composite AV. It is separate from Windows Remote Play.
