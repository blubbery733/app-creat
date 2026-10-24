#pragma once

#include <Arduino.h>
#include <WiFi.h>
#include <Update.h>
#include <Preferences.h>
#include <esp_wifi.h>
#include <esp_arduino_version.h>

#ifndef ESP_ARDUINO_VERSION_MAJOR
#define ESP_ARDUINO_VERSION_MAJOR 2
#endif

constexpr char FW_VERSION[] = "0.5.0-dev";
constexpr char AP_SSID[] = "PSR3";
constexpr char AP_PASSWORD[] = "psr3update";

constexpr uint8_t PIN_LED_RED     = 13;
constexpr uint8_t PIN_LED_GREEN   = 14;
constexpr uint8_t PIN_LED_YELLOW  = 16;
constexpr uint8_t PIN_BUZZER      = 17;
constexpr uint8_t PIN_VIDEO       = 25; // composite AV video only
constexpr uint8_t PIN_TOUCH_POWER = 27;
constexpr uint8_t PIN_PSU_ON      = 32;
constexpr uint8_t PIN_FAN_PWM     = 33;

constexpr bool PSU_CONTROL_ENABLED = true;
constexpr bool PSU_ON_ACTIVE_HIGH = true;
constexpr bool FAN_PWM_INVERTED = false;
constexpr bool TOUCH_ACTIVE_HIGH = true;

constexpr bool PAIRING_COMPAT_ACCEPT_ANY_4_DIGIT = true;
constexpr char PAIRING_CODE[] = "0000";

constexpr uint32_t DEBOUNCE_MS       = 45;
constexpr uint32_t FAN_BOOST_MS      = 1000;
constexpr uint32_t STATUS_PERIOD_MS  = 2000;
constexpr uint32_t POWER_HOLD_MS     = 5000;
constexpr uint32_t HTTP_TIMEOUT_MS   = 5000;
constexpr uint32_t UPDATE_TIMEOUT_MS = 30000;

constexpr uint32_t FAN_PWM_FREQ = 25000;
constexpr uint8_t FAN_PWM_BITS = 8;
constexpr uint8_t FAN_BOOT_PERCENT = 100;
constexpr uint8_t FAN_IDLE_PERCENT = 30;
constexpr uint8_t FAN_PWM_CHANNEL = 0;
constexpr uint8_t BUZZER_CHANNEL = 1;

constexpr uint32_t BUZZER_BASE_FREQ = 2800;
constexpr uint32_t BUTTON_BEEP_MS = 120;
constexpr uint32_t DOUBLE_BEEP_GAP_MS = 90;
constexpr uint8_t BUZZER_BITS = 8;

constexpr int STORAGE_TOTAL_MB = 2048;

IPAddress AP_IP(192, 168, 4, 1);
IPAddress AP_GATEWAY(192, 168, 4, 1);
IPAddress AP_SUBNET(255, 255, 255, 0);
WiFiServer httpServer(80);
Preferences prefs;

enum class SystemMode : uint8_t {
  Standby,
  Starting,
  On,
  ShuttingDown,
  SafeMode,
  UpdateMode,
  Error
};

SystemMode systemMode = SystemMode::Standby;
String lastError;
bool remotePaired = false;
bool restartScheduled = false;
uint32_t restartAtMs = 0;

bool lastRawButton = false;
bool stableButton = false;
uint32_t lastButtonChangeMs = 0;
uint32_t powerPressStartedMs = 0;
bool holdDoubleBeepSent = false;
bool holdBeepArmed = false;
uint32_t lastStatusMs = 0;

String installedGamesCsv;
