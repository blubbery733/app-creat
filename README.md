# PSR3 PC App

Windows companion application for the PSR3 ESP32 console project.

## Current v0.1

- Dashboard
- ESP32 address: `192.168.4.1`
- Mock Mode for testing without the console
- Remote Play placeholder
- Diagnostics placeholders for free heap and largest block
- HTTP/WebSocket protocol planned
- Recovery remains on the TV through AV

## Build

GitHub Actions builds the Windows release automatically on every push to `main`.

1. Open **Actions**
2. Open **Build PSR3 Windows**
3. Open the latest successful run
4. Download the **PSR3-Windows** artifact
5. Extract the whole archive and run the EXE from that folder

Do not move the EXE away from the DLL files and the `data` folder.
