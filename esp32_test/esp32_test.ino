#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <esp_heap_caps.h>

static const char* AP_SSID = "PSR3";
static const char* FW_VERSION = "PSR3-TEST-0.1";

constexpr uint8_t GREEN_LED_PIN = 14;
constexpr bool GREEN_LED_ACTIVE_HIGH = true;

WebServer server(80);

void setGreenLed(bool on) {
  const bool level = GREEN_LED_ACTIVE_HIGH ? on : !on;
  digitalWrite(GREEN_LED_PIN, level ? HIGH : LOW);
}

void sendJson(int code, const String& body) {
  server.sendHeader("Cache-Control", "no-store");
  server.send(code, "application/json; charset=utf-8", body);
}

String jsonEscape(const String& value) {
  String out;
  out.reserve(value.length() + 8);
  for (size_t i = 0; i < value.length(); ++i) {
    const char c = value[i];
    if (c == '"' || c == '\\') out += '\\';
    out += c;
  }
  return out;
}

void handleRoot() {
  server.send(
    200,
    "text/html; charset=utf-8",
    "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>"
    "<style>html,body{margin:0;width:100%;height:100%;background:#000;overflow:hidden}</style>"
    "</head><body></body></html>"
  );
}

void handleStatus() {
  const uint32_t freeHeap = ESP.getFreeHeap();
  const uint32_t largestBlock = heap_caps_get_largest_free_block(MALLOC_CAP_8BIT);
  const int32_t rssi = WiFi.RSSI();

  String body = "{";
  body += "\"ok\":true,";
  body += "\"firmware\":\"" + String(FW_VERSION) + "\",";
  body += "\"free_heap\":" + String(freeHeap) + ",";
  body += "\"largest_block\":" + String(largestBlock) + ",";
  body += "\"wifi_rssi\":" + String(rssi) + ",";
  body += "\"ip\":\"" + WiFi.softAPIP().toString() + "\"";
  body += "}";

  sendJson(200, body);
}

bool extractFourDigitCode(const String& body, String& code) {
  code = "";
  bool started = false;

  for (size_t i = 0; i < body.length(); ++i) {
    const char c = body[i];
    if (c >= '0' && c <= '9') {
      started = true;
      code += c;
      if (code.length() > 4) return false;
    } else if (started && code.length() < 4) {
      // Allow punctuation/JSON text around the code, but do not
      // accidentally combine two separate number groups.
      if (c == '"' || c == ' ' || c == ':' || c == ',' || c == '}') {
        continue;
      }
    }
  }

  return code.length() == 4;
}

void handleRemotePair() {
  const String raw = server.hasArg("plain") ? server.arg("plain") : "";
  String code;

  if (!extractFourDigitCode(raw, code)) {
    sendJson(400, "{\"ok\":false,\"error\":\"code_must_be_4_digits\"}");
    return;
  }

  sendJson(
    200,
    "{\"ok\":true,\"paired\":true,\"code\":\"" + jsonEscape(code) + "\"}"
  );
}

void handleRestart() {
  sendJson(200, "{\"ok\":true,\"restarting\":true}");
  delay(250);
  ESP.restart();
}

void handleUpdateMode() {
  sendJson(200, "{\"ok\":true,\"mode\":\"update_stub\"}");
}

void handleNotFound() {
  if (server.uri().startsWith("/api/")) {
    sendJson(404, "{\"ok\":false,\"error\":\"not_found\"}");
    return;
  }

  // Anything opened manually in a browser stays black.
  handleRoot();
}

void setup() {
  Serial.begin(115200);

  pinMode(GREEN_LED_PIN, OUTPUT);
  setGreenLed(false);

  WiFi.mode(WIFI_AP);

  const IPAddress localIp(192, 168, 4, 1);
  const IPAddress gateway(192, 168, 4, 1);
  const IPAddress subnet(255, 255, 255, 0);

  WiFi.softAPConfig(localIp, gateway, subnet);
  WiFi.softAP(AP_SSID);

  server.on("/", HTTP_GET, handleRoot);
  server.on("/api/status", HTTP_GET, handleStatus);
  server.on("/api/remote/pair", HTTP_POST, handleRemotePair);
  server.on("/api/restart", HTTP_POST, handleRestart);
  server.on("/api/update-mode", HTTP_POST, handleUpdateMode);
  server.onNotFound(handleNotFound);

  server.begin();
  setGreenLed(true);

  Serial.println();
  Serial.println("PSR3 test firmware ready");
  Serial.print("Wi-Fi: ");
  Serial.println(AP_SSID);
  Serial.print("IP: ");
  Serial.println(WiFi.softAPIP());
}

void loop() {
  server.handleClient();
  delay(2);
}
