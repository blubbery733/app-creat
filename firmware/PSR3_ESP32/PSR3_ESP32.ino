/*
  PSR3 ESP32 Firmware v0.5.0-dev
  Target: classic ESP32 / Arduino-ESP32 2.x or 3.x

  Wi-Fi AP:
    SSID: PSR3
    password: psr3update
    IP: 192.168.4.1

  GPIO25 is reserved for composite AV video only.
  ESP32 audio output is not used.

  Power button:
    Standby press -> one beep, red -> green + yellow, PSU ON.
    Hold the same power-on press for 5 seconds -> two extra beeps.
    On press -> green/yellow -> red immediately, PSU OFF, no beep.

  GPIO32 PSU_ON is enabled here using the existing low-voltage control path.
  The firmware explicitly drives PSU_ON to OFF during ESP32 startup before
  the normal power sequence begins.
*/

#include "psr3_config.h"
#include "psr3_hardware.h"
#include "psr3_games.h"
#include "psr3_network.h"

void setup() {
  Serial.begin(115200);
  delay(100);

  pinMode(PIN_LED_RED, OUTPUT);
  pinMode(PIN_LED_GREEN, OUTPUT);
  pinMode(PIN_LED_YELLOW, OUTPUT);
  pinMode(PIN_TOUCH_POWER, INPUT);

  if (PSU_CONTROL_ENABLED) {
    pinMode(PIN_PSU_ON, OUTPUT);
    digitalWrite(PIN_PSU_ON, PSU_ON_ACTIVE_HIGH ? LOW : HIGH);
  } else {
    pinMode(PIN_PSU_ON, INPUT);
  }

  prefs.begin("psr3", false);
  loadGameRegistry();

  const bool fanPwmOk = initFanPwm();
  const bool buzzerOk = initBuzzerPwm();

  enterStandby();

  if (!fanPwmOk || !buzzerOk) {
    systemMode = SystemMode::Error;
    lastError = "ledc_initialization_failed";
    setPsu(false);
    setFanPercent(0);
    setLeds(true, false, true);
  }

  startNetwork();

  Serial.println();
  Serial.print("[PSR3] Firmware ");
  Serial.println(FW_VERSION);
  Serial.print("[INIT] PSU control: ");
  Serial.println(PSU_CONTROL_ENABLED ? "ENABLED" : "DISABLED");
}

void loop() {
  if (restartScheduled &&
      static_cast<int32_t>(millis() - restartAtMs) >= 0) {
    delay(20);
    ESP.restart();
  }

  WiFiClient client = httpServer.available();
  if (client) {
    handleHttpClient(client);
  }

  if (systemMode != SystemMode::Error &&
      systemMode != SystemMode::UpdateMode &&
      systemMode != SystemMode::SafeMode) {
    updatePowerButton();
  }

  if (millis() - lastStatusMs >= STATUS_PERIOD_MS) {
    lastStatusMs = millis();
    printStatus();
  }

  delay(1);
}
