#pragma once

String jsonEscape(const String& input) {
  String out;
  out.reserve(input.length() + 8);

  for (size_t i = 0; i < input.length(); ++i) {
    const char c = input[i];
    switch (c) {
      case '\\': out += "\\\\"; break;
      case '"':  out += "\\\""; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      case '\t': out += "\\t"; break;
      default:
        if (static_cast<uint8_t>(c) >= 0x20) out += c;
        break;
    }
  }

  return out;
}

String readHttpLine(WiFiClient& client, uint32_t timeoutMs = HTTP_TIMEOUT_MS) {
  String line;
  const uint32_t started = millis();

  while (client.connected() && millis() - started < timeoutMs) {
    while (client.available()) {
      const char c = static_cast<char>(client.read());

      if (c == '\n') {
        if (line.endsWith("\r")) line.remove(line.length() - 1);
        return line;
      }

      if (line.length() < 1024) line += c;
    }

    delay(1);
  }

  return line;
}

bool readExactBody(
  WiFiClient& client,
  String& body,
  size_t length,
  uint32_t timeoutMs = HTTP_TIMEOUT_MS
) {
  body = "";
  if (length == 0) return true;
  if (length > 4096) return false;

  body.reserve(length);
  size_t received = 0;
  uint32_t lastData = millis();

  while (client.connected() && received < length) {
    const int availableBytes = client.available();

    if (availableBytes > 0) {
      const size_t toRead =
          min(static_cast<size_t>(availableBytes), length - received);

      for (size_t i = 0; i < toRead; ++i) {
        const int b = client.read();
        if (b < 0) break;
        body += static_cast<char>(b);
        ++received;
      }

      lastData = millis();
    } else {
      if (millis() - lastData > timeoutMs) return false;
      delay(1);
    }
  }

  return received == length;
}

void sendHttp(
  WiFiClient& client,
  int code,
  const char* status,
  const char* contentType,
  const String& body
) {
  client.print("HTTP/1.1 ");
  client.print(code);
  client.print(' ');
  client.println(status);
  client.print("Content-Type: ");
  client.println(contentType);
  client.print("Content-Length: ");
  client.println(body.length());
  client.println("Connection: close");
  client.println("Access-Control-Allow-Origin: *");
  client.println();
  client.print(body);
}

void sendJson(
  WiFiClient& client,
  int code,
  const char* status,
  const String& json
) {
  sendHttp(client, code, status, "application/json; charset=utf-8", json);
}

void sendError(
  WiFiClient& client,
  int code,
  const char* status,
  const String& error
) {
  sendJson(
    client,
    code,
    status,
    String("{\"ok\":false,\"error\":\"") + jsonEscape(error) + "\"}"
  );
}

String extractJsonString(const String& body, const char* key) {
  const String needle = String("\"") + key + "\"";
  int p = body.indexOf(needle);
  if (p < 0) return "";

  p = body.indexOf(':', p + needle.length());
  if (p < 0) return "";
  ++p;

  while (p < static_cast<int>(body.length()) &&
         (body[p] == ' ' ||
          body[p] == '\t' ||
          body[p] == '\r' ||
          body[p] == '\n')) {
    ++p;
  }

  if (p >= static_cast<int>(body.length()) || body[p] != '"') return "";
  ++p;

  String value;
  while (p < static_cast<int>(body.length())) {
    const char c = body[p++];
    if (c == '"') break;

    if (c == '\\' && p < static_cast<int>(body.length())) {
      value += body[p++];
    } else {
      value += c;
    }
  }

  return value;
}

int extractJsonInt(const String& body, const char* key, int fallback = -1) {
  const String needle = String("\"") + key + "\"";
  int p = body.indexOf(needle);
  if (p < 0) return fallback;

  p = body.indexOf(':', p + needle.length());
  if (p < 0) return fallback;
  ++p;

  while (p < static_cast<int>(body.length()) &&
         (body[p] == ' ' ||
          body[p] == '\t' ||
          body[p] == '\r' ||
          body[p] == '\n')) {
    ++p;
  }

  int sign = 1;
  if (p < static_cast<int>(body.length()) && body[p] == '-') {
    sign = -1;
    ++p;
  }

  int value = 0;
  bool any = false;

  while (p < static_cast<int>(body.length()) &&
         body[p] >= '0' &&
         body[p] <= '9') {
    any = true;
    value = value * 10 + (body[p] - '0');
    ++p;
  }

  return any ? value * sign : fallback;
}

bool isFourDigitCode(const String& value) {
  if (value.length() != 4) return false;

  for (size_t i = 0; i < value.length(); ++i) {
    if (value[i] < '0' || value[i] > '9') return false;
  }

  return true;
}

int connectedClientRssi() {
  wifi_sta_list_t stations;
  memset(&stations, 0, sizeof(stations));

  if (esp_wifi_ap_get_sta_list(&stations) != ESP_OK || stations.num <= 0) {
    return 0;
  }

  int bestRssi = -127;

  for (int i = 0; i < stations.num; ++i) {
    if (stations.sta[i].rssi > bestRssi) {
      bestRssi = stations.sta[i].rssi;
    }
  }

  return bestRssi;
}

String statusJson() {
  String json = "{";
  json += "\"ok\":true";
  json += ",\"firmware\":\"" + String(FW_VERSION) + "\"";
  json += ",\"ip\":\"" + WiFi.softAPIP().toString() + "\"";
  json += ",\"free_heap\":" + String(ESP.getFreeHeap());
  json += ",\"largest_block\":" + String(ESP.getMaxAllocHeap());

  const int clientRssi = connectedClientRssi();
  if (clientRssi == 0) {
    json += ",\"wifi_rssi\":null";
  } else {
    json += ",\"wifi_rssi\":" + String(clientRssi);
  }

  json += ",\"mode\":\"" + String(modeName(systemMode)) + "\"";
  json += ",\"state\":\"" + String(stateName(systemMode)) + "\"";

  json += ",\"error\":";
  if (lastError.length()) {
    json += "\"" + jsonEscape(lastError) + "\"";
  } else {
    json += "null";
  }

  json += ",\"psu_control_enabled\":";
  json += PSU_CONTROL_ENABLED ? "true" : "false";
  json += ",\"paired\":";
  json += remotePaired ? "true" : "false";
  json += ",\"clients\":" + String(WiFi.softAPgetStationNum());
  json += ",\"fan_percent\":" + String(currentFanPercent);
  json += ",\"installed_games\":" + installedGamesJsonArray();
  json += ",\"storage_used_mb\":" + String(installedStorageMb());
  json += ",\"storage_total_mb\":" + String(STORAGE_TOTAL_MB);
  json += "}";

  return json;
}

bool streamFirmwareBody(
  WiFiClient& client,
  size_t contentLength,
  String& errorOut
) {
  if (contentLength == 0) {
    errorOut = "empty_firmware";
    return false;
  }

  if (!Update.begin(contentLength, U_FLASH)) {
    errorOut = String("update_begin_failed_") + Update.errorString();
    return false;
  }

  uint8_t buffer[1024];
  size_t received = 0;
  uint32_t lastData = millis();

  while (client.connected() && received < contentLength) {
    const int availableBytes = client.available();

    if (availableBytes > 0) {
      const size_t remaining = contentLength - received;
      const size_t toRead =
          min(min(static_cast<size_t>(availableBytes), remaining), sizeof(buffer));

      const int count = client.read(buffer, toRead);

      if (count > 0) {
        const size_t written =
            Update.write(buffer, static_cast<size_t>(count));

        if (written != static_cast<size_t>(count)) {
          errorOut = String("update_write_failed_") + Update.errorString();
          Update.abort();
          return false;
        }

        received += written;
        lastData = millis();
      }
    } else {
      if (millis() - lastData > UPDATE_TIMEOUT_MS) {
        errorOut = "update_upload_timeout";
        Update.abort();
        return false;
      }

      delay(1);
    }
  }

  if (received != contentLength) {
    errorOut = "incomplete_firmware";
    Update.abort();
    return false;
  }

  if (!Update.end()) {
    errorOut = String("update_end_failed_") + Update.errorString();
    return false;
  }

  return true;
}

void handleHttpClient(WiFiClient client) {
  client.setTimeout(HTTP_TIMEOUT_MS);

  const String requestLine = readHttpLine(client);
  if (requestLine.length() == 0) {
    client.stop();
    return;
  }

  const int firstSpace = requestLine.indexOf(' ');
  const int secondSpace = requestLine.indexOf(' ', firstSpace + 1);

  if (firstSpace <= 0 || secondSpace <= firstSpace) {
    sendError(client, 400, "Bad Request", "bad_request_line");
    client.stop();
    return;
  }

  const String method = requestLine.substring(0, firstSpace);
  String target = requestLine.substring(firstSpace + 1, secondSpace);

  size_t contentLength = 0;
  String xFilename;

  while (client.connected()) {
    const String line = readHttpLine(client);
    if (line.length() == 0) break;

    const int colon = line.indexOf(':');
    if (colon <= 0) continue;

    String key = line.substring(0, colon);
    String value = line.substring(colon + 1);
    key.toLowerCase();
    value.trim();

    if (key == "content-length") {
      contentLength = static_cast<size_t>(value.toInt());
    } else if (key == "x-filename") {
      xFilename = value;
    }
  }

  const int queryPos = target.indexOf('?');
  const String path =
      queryPos >= 0 ? target.substring(0, queryPos) : target;

  if (method == "POST" && path == "/api/update/firmware") {
    if (systemMode != SystemMode::UpdateMode) {
      sendError(client, 409, "Conflict", "not_in_update_mode");
      client.stop();
      return;
    }

    String updateError;
    if (!streamFirmwareBody(client, contentLength, updateError)) {
      lastError = updateError;
      systemMode = SystemMode::Error;
      setLeds(true, false, true);
      sendError(client, 500, "Internal Server Error", updateError);
      client.stop();
      return;
    }

    sendHttp(client, 200, "OK", "text/plain; charset=utf-8", "OK");
    client.flush();
    delay(40);
    client.stop();
    scheduleRestart(650);
    return;
  }

  String body;
  if (contentLength > 0) {
    if (!readExactBody(client, body, contentLength)) {
      sendError(client, 413, "Payload Too Large", "body_read_failed");
      client.stop();
      return;
    }
  }

  if (method == "GET" && path == "/api/status") {
    sendJson(client, 200, "OK", statusJson());
  }
  else if (method == "GET" && path == "/api/games") {
    sendJson(
      client,
      200,
      "OK",
      String("{\"ok\":true,\"installed_games\":") +
      installedGamesJsonArray() +
      ",\"storage_used_mb\":" +
      installedStorageMb() +
      ",\"storage_total_mb\":" +
      STORAGE_TOTAL_MB +
      "}"
    );
  }
  else if (method == "POST" && path == "/api/game/install") {
    const int gameId = extractJsonInt(body, "gameId");

    if (gameId <= 0) {
      sendError(client, 400, "Bad Request", "bad_game_id");
    } else {
      addInstalledGame(gameId);
      sendJson(
        client,
        200,
        "OK",
        String("{\"ok\":true,\"installed\":true,\"gameId\":") +
        gameId +
        ",\"storage_used_mb\":" +
        installedStorageMb() +
        "}"
      );
    }
  }
  else if (method == "POST" && path == "/api/game/remove") {
    const int gameId = extractJsonInt(body, "gameId");

    if (gameId <= 0) {
      sendError(client, 400, "Bad Request", "bad_game_id");
    } else {
      removeInstalledGame(gameId);
      sendJson(
        client,
        200,
        "OK",
        String("{\"ok\":true,\"installed\":false,\"gameId\":") +
        gameId +
        ",\"storage_used_mb\":" +
        installedStorageMb() +
        "}"
      );
    }
  }
  else if (method == "POST" && path == "/api/remote/pair") {
    const String code = extractJsonString(body, "code");
    const bool validFormat = isFourDigitCode(code);
    const bool accepted =
        validFormat &&
        (PAIRING_COMPAT_ACCEPT_ANY_4_DIGIT || code == PAIRING_CODE);

    remotePaired = accepted;

    if (accepted) {
      sendJson(client, 200, "OK", "{\"ok\":true,\"paired\":true}");
    } else {
      sendJson(
        client,
        403,
        "Forbidden",
        "{\"ok\":false,\"paired\":false,\"error\":\"bad_pair_code\"}"
      );
    }
  }
  else if (method == "POST" && path == "/api/power/on") {
    if (systemMode == SystemMode::SafeMode ||
        systemMode == SystemMode::UpdateMode) {
      sendError(client, 409, "Conflict", "mode_blocks_power_on");
    } else {
      if (systemMode == SystemMode::Standby) startPSR3();

      sendJson(
        client,
        200,
        "OK",
        String("{\"ok\":true,\"mode\":\"") +
        modeName(systemMode) +
        "\",\"psu_control_enabled\":" +
        (PSU_CONTROL_ENABLED ? "true" : "false") +
        "}"
      );
    }
  }
  else if (method == "POST" && path == "/api/power/standby") {
    if (systemMode == SystemMode::On ||
        systemMode == SystemMode::Starting) {
      shutdownPSR3();
    } else if (systemMode == SystemMode::UpdateMode) {
      enterStandby();
    }

    sendJson(client, 200, "OK", "{\"ok\":true,\"mode\":\"standby\"}");
  }
  else if (method == "POST" && path == "/api/update-mode") {
    enterUpdateMode();
    sendJson(client, 200, "OK", "{\"ok\":true,\"mode\":\"update_mode\"}");
  }
  else if (method == "POST" && path == "/api/restart") {
    sendJson(client, 200, "OK", "{\"ok\":true,\"restarting\":true}");
    client.flush();
    scheduleRestart();
  }
  else if (method == "POST" &&
           (path == "/game" || path == "/api/game")) {
    int gameId = extractJsonInt(body, "gameId");

    if (gameId <= 0 && queryPos >= 0) {
      const int idPos = target.indexOf("id=");
      if (idPos >= 0) {
        gameId = target.substring(idPos + 3).toInt();
      }
    }

    if (gameId > 0) addInstalledGame(gameId);

    sendJson(
      client,
      200,
      "OK",
      String("{\"ok\":true,\"accepted\":true,\"installed_games\":") +
      installedGamesJsonArray() +
      "}"
    );
  }
  else if (method == "GET" && path == "/") {
    sendJson(client, 200, "OK", "{\"ok\":true,\"device\":\"PSR3\"}");
  }
  else {
    sendError(client, 404, "Not Found", "not_found");
  }

  delay(2);
  client.stop();
}

void startNetwork() {
  WiFi.mode(WIFI_AP);
  WiFi.softAPdisconnect(false);
  delay(50);

  if (!WiFi.softAPConfig(AP_IP, AP_GATEWAY, AP_SUBNET)) {
    lastError = "softap_config_failed";
  }

  if (!WiFi.softAP(AP_SSID, AP_PASSWORD)) {
    lastError = "softap_start_failed";
    systemMode = SystemMode::Error;
    setLeds(true, false, true);
    return;
  }

  httpServer.begin();

  Serial.print("[WIFI] SSID: ");
  Serial.println(AP_SSID);
  Serial.print("[WIFI] IP: ");
  Serial.println(WiFi.softAPIP());
  Serial.println("[HTTP] API listening on port 80");
}

void printStatus() {
  Serial.print("[STATUS] mode=");
  Serial.print(modeName(systemMode));
  Serial.print(" freeHeap=");
  Serial.print(ESP.getFreeHeap());
  Serial.print(" clients=");
  Serial.print(WiFi.softAPgetStationNum());
  Serial.print(" games=");
  Serial.println(installedGamesCsv);
}
