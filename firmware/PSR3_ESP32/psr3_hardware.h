#pragma once

const char* modeName(SystemMode mode) {
  switch (mode) {
    case SystemMode::Standby:      return "standby";
    case SystemMode::Starting:     return "starting";
    case SystemMode::On:           return "on";
    case SystemMode::ShuttingDown: return "shutting_down";
    case SystemMode::SafeMode:     return "safe_mode";
    case SystemMode::UpdateMode:   return "update_mode";
    case SystemMode::Error:        return "error";
  }
  return "unknown";
}

const char* stateName(SystemMode mode) {
  switch (mode) {
    case SystemMode::Standby:      return "STANDBY";
    case SystemMode::Starting:     return "STARTING";
    case SystemMode::On:           return "READY";
    case SystemMode::ShuttingDown: return "SHUTDOWN";
    case SystemMode::SafeMode:     return "SAFE_MODE";
    case SystemMode::UpdateMode:   return "UPDATE_MODE";
    case SystemMode::Error:        return "ERROR";
  }
  return "UNKNOWN";
}

void setLeds(bool red, bool green, bool yellow) {
  digitalWrite(PIN_LED_RED, red ? HIGH : LOW);
  digitalWrite(PIN_LED_GREEN, green ? HIGH : LOW);
  digitalWrite(PIN_LED_YELLOW, yellow ? HIGH : LOW);
}

void setPsu(bool enabled) {
  if (!PSU_CONTROL_ENABLED) return;
  const bool level = enabled ? PSU_ON_ACTIVE_HIGH : !PSU_ON_ACTIVE_HIGH;
  digitalWrite(PIN_PSU_ON, level ? HIGH : LOW);
}

bool initFanPwm() {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  return ledcAttach(PIN_FAN_PWM, FAN_PWM_FREQ, FAN_PWM_BITS);
#else
  const double actualFreq = ledcSetup(FAN_PWM_CHANNEL, FAN_PWM_FREQ, FAN_PWM_BITS);
  ledcAttachPin(PIN_FAN_PWM, FAN_PWM_CHANNEL);
  return actualFreq > 0;
#endif
}

bool initBuzzerPwm() {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  return ledcAttach(PIN_BUZZER, BUZZER_BASE_FREQ, BUZZER_BITS);
#else
  const double actualFreq = ledcSetup(BUZZER_CHANNEL, BUZZER_BASE_FREQ, BUZZER_BITS);
  ledcAttachPin(PIN_BUZZER, BUZZER_CHANNEL);
  return actualFreq > 0;
#endif
}

void setFanPercent(uint8_t percent) {
  if (percent > 100) percent = 100;
  currentFanPercent = percent;
  uint32_t duty = map(percent, 0, 100, 0, 255);
  if (FAN_PWM_INVERTED) duty = 255 - duty;
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcWrite(PIN_FAN_PWM, duty);
#else
  ledcWrite(FAN_PWM_CHANNEL, duty);
#endif
}

void buzzerTone(uint32_t frequency) {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcWriteTone(PIN_BUZZER, frequency);
#else
  ledcWriteTone(BUZZER_CHANNEL, frequency);
#endif
}

void beep(uint32_t frequency, uint32_t durationMs) {
  buzzerTone(frequency);
  delay(durationMs);
  buzzerTone(0);
}

void buttonBeepOnce() {
  beep(BUZZER_BASE_FREQ, BUTTON_BEEP_MS);
}

void buttonBeepTwice() {
  beep(BUZZER_BASE_FREQ, BUTTON_BEEP_MS);
  delay(DOUBLE_BEEP_GAP_MS);
  beep(BUZZER_BASE_FREQ, BUTTON_BEEP_MS);
}

bool readPowerSensor() {
  const bool rawHigh = digitalRead(PIN_TOUCH_POWER) == HIGH;
  return TOUCH_ACTIVE_HIGH ? rawHigh : !rawHigh;
}

void enterStandby();
void startPSR3();
void shutdownPSR3();

void handlePowerPress() {
  powerPressStartedMs = millis();
  holdDoubleBeepSent = false;
  holdBeepArmed = false;

  if (systemMode == SystemMode::Standby) {
    holdBeepArmed = true;
    buttonBeepOnce();
    startPSR3();
  } else if (systemMode == SystemMode::On ||
             systemMode == SystemMode::Starting) {
    shutdownPSR3();
  }
}

void updatePowerButton() {
  const bool raw = readPowerSensor();

  if (raw != lastRawButton) {
    lastRawButton = raw;
    lastButtonChangeMs = millis();
  }

  if ((millis() - lastButtonChangeMs) >= DEBOUNCE_MS && raw != stableButton) {
    stableButton = raw;
    if (stableButton) {
      handlePowerPress();
    } else {
      powerPressStartedMs = 0;
      holdDoubleBeepSent = false;
      holdBeepArmed = false;
    }
  }

  if (stableButton && holdBeepArmed && !holdDoubleBeepSent &&
      powerPressStartedMs != 0 &&
      (millis() - powerPressStartedMs) >= POWER_HOLD_MS) {
    buttonBeepTwice();
    holdDoubleBeepSent = true;
  }
}

void enterStandby() {
  setFanPercent(0);
  setPsu(false);
  setLeds(true, false, false);
  systemMode = SystemMode::Standby;
  Serial.println("[PSR3] STANDBY");
}

void enterSafeMode() {
  setPsu(false);
  setFanPercent(0);
  setLeds(true, false, true);
  systemMode = SystemMode::SafeMode;
  Serial.println("[PSR3] SAFE MODE");
}

void startPSR3() {
  if (systemMode != SystemMode::Standby) return;

  systemMode = SystemMode::Starting;
  lastError = "";

  // Red -> green + yellow immediately.
  setLeds(false, true, true);

  // Start the 25 kHz fan PWM immediately after the 12 V rail is enabled.
  // Using a real PWM duty (not 100% constant HIGH) makes startup more reliable
  // for the original PS3 3-wire fan controller.
  setPsu(true);
  setFanPercent(FAN_BOOT_PERCENT);
  delay(FAN_BOOST_MS);
  setFanPercent(FAN_IDLE_PERCENT);

  setLeds(false, true, true);
  systemMode = SystemMode::On;
  Serial.println("[BOOT] READY");
}

void shutdownPSR3() {
  if (systemMode != SystemMode::On && systemMode != SystemMode::Starting) return;

  systemMode = SystemMode::ShuttingDown;

  // Green/yellow -> red immediately and silently.
  setLeds(true, false, false);
  setPsu(false);
  setFanPercent(0);

  systemMode = SystemMode::Standby;
  Serial.println("[POWER] STANDBY");
}

void enterUpdateMode() {
  if (systemMode == SystemMode::On) {
    setPsu(false);
    setFanPercent(0);
  }

  setLeds(false, false, true);
  systemMode = SystemMode::UpdateMode;
  lastError = "";
  Serial.println("[PSR3] UPDATE MODE");
}

void scheduleRestart(uint32_t delayMs = 450) {
  restartScheduled = true;
  restartAtMs = millis() + delayMs;
}
