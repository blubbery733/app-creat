# PSR3 PC App

Windows companion application for the PSR3 ESP32 console project.

## Current app

- PlayStation-app-inspired dark/blue interface
- Start screen with **ESP32** and **Remote Play**
- Working **Dashboard** and **Settings** navigation
- Default Wi-Fi: `PSR3`
- Default ESP32 IP: `192.168.4.1`
- Real connection probe: `http://192.168.4.1/api/status`
- Remote Play pairing UI with an exact 4-digit code
- Demo mode for UI testing
- Recovery remains on the TV through AV

## Build

GitHub Actions builds the Windows release automatically on every push to `main`.

1. Open **Actions**
2. Open **Build PSR3 Windows**
3. Open the latest successful run
4. Download the **PSR3-Windows** artifact
5. Extract the whole archive and run the EXE from that folder

Keep the EXE together with its DLL files and the `data` folder.
