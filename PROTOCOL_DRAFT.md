# PSR3 protocol draft

Default Wi-Fi: `PSR3`
Default ESP32 address: `192.168.4.1`
Status endpoint: `/api/status`

Full local status URL:

`http://192.168.4.1/api/status`

## ESP32 connection

The Windows app performs an HTTP GET request to:

`http://<PSR3-IP>/api/status`

A successful 2xx response means the ESP32 is reachable.

## Remote Play pairing

- Network is selected/entered manually.
- Confirmation code must contain exactly 4 digits.
- The current app implements the pairing UI and validation.
- The real Remote Play transport can be added later.

## Planned status JSON

The app can later read fields such as:

- power state
- free heap
- largest free block
- Wi-Fi RSSI
- firmware version

## Planned commands

- power / shutdown
- restart
- fan control
- Remote Play state
- Update Mode

## Recovery

Recovery stays on the console itself and is displayed on the TV over composite AV.
