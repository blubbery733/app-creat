# PSR3 ESP32 test firmware

Minimal firmware for testing the Windows PSR3 app.

- ESP32 AP SSID: `PSR3`
- IP: `192.168.4.1`
- Green LED: GPIO14
- Browser root: black page
- `GET /api/status`
- `POST /api/remote/pair`
- `POST /api/restart`
- `POST /api/update-mode`

The Remote Play pairing endpoint accepts any 4-digit code in this test build.

The firmware intentionally does not control the PSU, fan, AV output, buzzer, red LED, or yellow LED.
