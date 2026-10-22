# PSR3 protocol draft

## Network

Default PSR3 Wi-Fi: `PSR3`

Default ESP32 address:

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
  "firmware": "0.1.0",
  "free_heap": 0,
  "largest_block": 0,
  "wifi_rssi": -50
}
```

### Remote Play pairing

`POST /api/remote/pair`

Request:

```json
{
  "code": "1234"
}
```

A 2xx response means that the code shown on the TV was accepted.

### Restart

`POST /api/restart`

### Update Mode

`POST /api/update-mode`

## Future Remote Play transport

The Windows Remote Play surface is intentionally black for now. Later it will be used by the renderer/stream created after the Scratch/SB3 project is ported.

A future transport may use a WebSocket such as:

`ws://192.168.4.1/ws/stream`

The exact stream format is intentionally left open until the ESP32-side renderer is ready.

## Recovery

Recovery remains on the console itself and is displayed on the TV over composite AV. It is not part of the Windows Remote Play screen.
