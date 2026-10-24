#pragma once

int gameSizeMb(int id) {
  switch (id) {
    case 101: return 248;
    case 102: return 176;
    case 103: return 88;
    case 104: return 132;
    case 105: return 310;
    case 106: return 41;
    case 107: return 427;
    default:  return 0;
  }
}

bool csvContainsGame(const String& csv, int id) {
  const String token = String(",") + String(id) + ",";
  const String wrapped = String(",") + csv + ",";
  return wrapped.indexOf(token) >= 0;
}

bool isGameInstalled(int id) {
  return csvContainsGame(installedGamesCsv, id);
}

void normalizeGamesCsv() {
  while (installedGamesCsv.startsWith(",")) {
    installedGamesCsv.remove(0, 1);
  }
  while (installedGamesCsv.endsWith(",")) {
    installedGamesCsv.remove(installedGamesCsv.length() - 1);
  }
  while (installedGamesCsv.indexOf(",,") >= 0) {
    installedGamesCsv.replace(",,", ",");
  }
}

void saveGameRegistry() {
  normalizeGamesCsv();
  prefs.putString("games", installedGamesCsv);
}

void loadGameRegistry() {
  installedGamesCsv = prefs.getString("games", "");
  normalizeGamesCsv();
}

bool addInstalledGame(int id) {
  if (id <= 0) return false;
  if (isGameInstalled(id)) return true;

  if (installedGamesCsv.length()) installedGamesCsv += ",";
  installedGamesCsv += String(id);
  saveGameRegistry();
  return true;
}

bool removeInstalledGame(int id) {
  if (!isGameInstalled(id)) return true;

  String next;
  int start = 0;

  while (start < static_cast<int>(installedGamesCsv.length())) {
    int comma = installedGamesCsv.indexOf(',', start);
    if (comma < 0) comma = installedGamesCsv.length();

    const String item = installedGamesCsv.substring(start, comma);
    if (item.length() && item.toInt() != id) {
      if (next.length()) next += ",";
      next += item;
    }

    start = comma + 1;
  }

  installedGamesCsv = next;
  saveGameRegistry();
  return true;
}

int installedStorageMb() {
  int used = 0;
  int start = 0;

  while (start < static_cast<int>(installedGamesCsv.length())) {
    int comma = installedGamesCsv.indexOf(',', start);
    if (comma < 0) comma = installedGamesCsv.length();

    const int id = installedGamesCsv.substring(start, comma).toInt();
    used += gameSizeMb(id);
    start = comma + 1;
  }

  return used;
}

String installedGamesJsonArray() {
  String json = "[";
  int start = 0;
  bool first = true;

  while (start < static_cast<int>(installedGamesCsv.length())) {
    int comma = installedGamesCsv.indexOf(',', start);
    if (comma < 0) comma = installedGamesCsv.length();

    const int id = installedGamesCsv.substring(start, comma).toInt();
    if (id > 0) {
      if (!first) json += ",";
      json += String(id);
      first = false;
    }

    start = comma + 1;
  }

  json += "]";
  return json;
}
