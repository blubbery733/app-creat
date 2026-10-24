/*
  PSR3 ESP32 Firmware v0.2
  Target: ESP32 / Arduino-ESP32 3.3.12

  Confirmed low-voltage pin map:
    GPIO13  Red LED
    GPIO14  Green LED
    GPIO16  Yellow LED
    GPIO17  Buzzer
    GPIO25  Composite video (reserved for next stage)
    GPIO26  Audio output (reserved for next stage)
    GPIO27  Power touch sensor OUT
    GPIO32  APS-231 PSU_ON control
    GPIO33  PS3 fan PWM/control

  This stage intentionally contains only the hardware/power foundation.
  AV video, audio, Wi-Fi, gamepad and Recovery will be added next.
*/

#include <Arduino.h>

constexpr char FW_VERSION[] = "0.2.0-dev";

// ---------- Pin map ----------
constexpr uint8_t PIN_LED_RED     = 13;
constexpr uint8_t PIN_LED_GREEN   = 14;
constexpr uint8_t PIN_LED_YELLOW  = 16;
constexpr uint8_t PIN_BUZZER      = 17;
constexpr uint8_t PIN_VIDEO       = 25; // reserved
constexpr uint8_t PIN_AUDIO       = 26; // reserved
constexpr uint8_t PIN_TOUCH_POWER = 27;
constexpr uint8_t PIN_PSU_ON      = 32;
constexpr uint8_t PIN_FAN_PWM     = 33;

// ---------- Hardware configuration ----------
// The project wiring has been treated as active-HIGH for PSU_ON.
// Change only this flag if the low-voltage driver is later found to invert it.
constexpr bool PSU_CONTROL_ENABLED = false;
constexpr bool PSU_ON_ACTIVE_HIGH = true;

// Keep this configurable because PS3 fan control may be inverted depending
// on the final interface/driver.
constexpr bool FAN_PWM_INVERTED = false;

constexpr bool TOUCH_ACTIVE_HIGH = true;

// ---------- Timing ----------
constexpr uint32_t DEBOUNCE_MS       = 45;
constexpr uint32_t FAN_BOOST_MS      = 1000;
constexpr uint32_t STATUS_PERIOD_MS  = 5000;

// ---------- Fan ----------
constexpr uint32_t FAN_PWM_FREQ = 25000;
constexpr uint8_t  FAN_PWM_BITS = 8;
constexpr uint8_t  FAN_BOOT_PERCENT = 100;
constexpr uint8_t  FAN_IDLE_PERCENT = 30;

// ---------- Buzzer ----------
constexpr uint32_t BUZZER_BASE_FREQ = 2000;
constexpr uint8_t  BUZZER_BITS      = 8;

enum class SystemState : uint8_t {
  Standby,
  Starting,
  Ready,
  ShuttingDown,
  Error
};

SystemState state = SystemState::Standby;

bool lastRawButton = false;
bool stableButton = false;
uint32_t lastButtonChangeMs = 0;
uint32_t lastStatusMs = 0;

const char* stateName(SystemState s) {
  switch (s) {
    case SystemState::Standby:      return "STANDBY";
    case SystemState::Starting:     return "STARTING";
    case SystemState::Ready:        return "READY";
    case SystemState::ShuttingDown: return "SHUTDOWN";
    case SystemState::Error:        return "ERROR";
  }
  return "UNKNOWN";
}

void setLeds(bool red, bool green, bool yellow) {
  digitalWrite(PIN_LED_RED, red ? HIGH : LOW);
  digitalWrite(PIN_LED_GREEN, green ? HIGH : LOW);
  digitalWrite(PIN_LED_YELLOW, yellow ? HIGH : LOW);
}

void setPsu(bool enabled) {
  if (!PSU_CONTROL_ENABLED) {
    return;
  }

  const bool level = enabled ? PSU_ON_ACTIVE_HIGH : !PSU_ON_ACTIVE_HIGH;
  digitalWrite(PIN_PSU_ON, level ? HIGH : LOW);
}

void setFanPercent(uint8_t percent) {
  if (percent > 100) percent = 100;

  uint32_t duty = map(percent, 0, 100, 0, 255);
  if (FAN_PWM_INVERTED) duty = 255 - duty;

  ledcWrite(PIN_FAN_PWM, duty);
}

void beep(uint32_t frequency, uint32_t durationMs) {
  ledcWriteTone(PIN_BUZZER, frequency);
  delay(durationMs);
  ledcWriteTone(PIN_BUZZER, 0);
}

bool readPowerSensor() {
  const bool rawHigh = digitalRead(PIN_TOUCH_POWER) == HIGH;
  return TOUCH_ACTIVE_HIGH ? rawHigh : !rawHigh;
}

bool powerPressedEvent() {
  const bool raw = readPowerSensor();

  if (raw != lastRawButton) {
    lastRawButton = raw;
    lastButtonChangeMs = millis();
  }

  if ((millis() - lastButtonChangeMs) >= DEBOUNCE_MS &&
      raw != stableButton) {
    stableButton = raw;
    if (stableButton) return true;
  }

  return false;
}

void enterStandby() {
  setFanPercent(0);
  setPsu(false);
  setLeds(true, false, false);
  state = SystemState::Standby;

  Serial.println("[PSR3] STANDBY");
}

void startPSR3() {
  if (state != SystemState::Standby) return;

  state = SystemState::Starting;
  Serial.println();
  Serial.println("==================================");
  Serial.print(" PSR3 ESP32 Firmware ");
  Serial.println(FW_VERSION);
  Serial.println("==================================");

  // Red OFF, yellow ON while booting.
  setLeds(false, false, true);
  beep(1350, 80);

  // Enable the APS-231 main rail using the low-voltage PSU_ON interface.
  setPsu(true);
  delay(250);

  // Fan startup boost.
  setFanPercent(FAN_BOOT_PERCENT);
  Serial.println("[BOOT] Fan boost 100%");
  delay(FAN_BOOST_MS);

  // Until temperature control is added, keep a conservative fixed idle speed.
  setFanPercent(FAN_IDLE_PERCENT);
  Serial.print("[BOOT] Fan idle ");
  Serial.print(FAN_IDLE_PERCENT);
  Serial.println("%");

  // Boot completed.
  setLeds(false, true, false);
  state = SystemState::Ready;
  beep(1650, 90);

  Serial.println("[BOOT] READY");
  Serial.println("[BOOT] AV/Wi-Fi/Recovery: next firmware stage");
}

void shutdownPSR3() {
  if (state != SystemState::Ready) return;

  state = SystemState::ShuttingDown;
  Serial.println("[POWER] Shutting down...");

  setLeds(false, false, true);
  beep(900, 100);

  // Give the fan a short moment before the main rail is removed.
  setFanPercent(FAN_IDLE_PERCENT);
  delay(300);

  setPsu(false);
  setFanPercent(0);

  setLeds(true, false, false);
  state = SystemState::Standby;

  Serial.println("[POWER] STANDBY");
}

void printStatus() {
  Serial.print("[STATUS] state=");
  Serial.print(stateName(state));
  Serial.print(" freeHeap=");
  Serial.print(ESP.getFreeHeap());
  Serial.print(" largestBlock=");
  Serial.println(ESP.getMaxAllocHeap());
}

void setup() {
  Serial.begin(115200);
  delay(100);

  pinMode(PIN_LED_RED, OUTPUT);
  pinMode(PIN_LED_GREEN, OUTPUT);
  pinMode(PIN_LED_YELLOW, OUTPUT);
  pinMode(PIN_TOUCH_POWER, INPUT);

  // Safe first-build behavior: do not drive APS-231 PSU_ON until its
  // low-voltage control polarity/interface is confirmed.
  if (PSU_CONTROL_ENABLED) {
    pinMode(PIN_PSU_ON, OUTPUT);
  } else {
    pinMode(PIN_PSU_ON, INPUT);
  }

  // Arduino-ESP32 3.x LEDC API: channel assignment is automatic per pin.
  const bool fanPwmOk = ledcAttach(PIN_FAN_PWM, FAN_PWM_FREQ, FAN_PWM_BITS);
  const bool buzzerOk = ledcAttach(PIN_BUZZER, BUZZER_BASE_FREQ, BUZZER_BITS);

  // GPIO25/26 are intentionally left untouched until AV is added.

  enterStandby();

  Serial.println();
  Serial.print("[PSR3] Firmware ");
  Serial.println(FW_VERSION);
  Serial.println("[PSR3] Hardware foundation loaded");
  Serial.print("[INIT] PSU control: ");
  Serial.println(PSU_CONTROL_ENABLED ? "ENABLED" : "SAFE TEST / DISABLED");
  Serial.print("[INIT] Fan PWM: ");
  Serial.println(fanPwmOk ? "OK" : "ERROR");
  Serial.print("[INIT] Buzzer PWM: ");
  Serial.println(buzzerOk ? "OK" : "ERROR");

  if (!fanPwmOk || !buzzerOk) {
    state = SystemState::Error;
    setPsu(false);
    setFanPercent(0);
    setLeds(true, false, true);
    Serial.println("[ERROR] LEDC initialization failed");
  }
}

void loop() {
  if (state != SystemState::Error && powerPressedEvent()) {
    if (state == SystemState::Standby) {
      startPSR3();
    } else if (state == SystemState::Ready) {
      shutdownPSR3();
    }
  }

  if ((millis() - lastStatusMs) >= STATUS_PERIOD_MS) {
    lastStatusMs = millis();
    printStatus();
  }

  delay(2);
}
