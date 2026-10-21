# PSR3 protocol draft

Default ESP32 address: `192.168.4.1`

## Planned transport

- HTTP: commands, configuration and status
- WebSocket: live status and telemetry

## Planned status data

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

Recovery is intentionally kept on the console itself and displayed over composite AV rather than depending on the Windows app.
