#include "storage.h"

#include <Preferences.h>

#include "config.h"

namespace {

Preferences prefs;
constexpr char NAMESPACE[] = "speaker";

}  // namespace

namespace Storage {

void begin() { prefs.begin(NAMESPACE, false); }

uint8_t loadVolume() { return prefs.getUChar("volume", 50); }
void saveVolume(uint8_t volume) { prefs.putUChar("volume", volume); }

uint8_t loadSource() { return prefs.getUChar("source", 0); }
void saveSource(uint8_t source) { prefs.putUChar("source", source); }

size_t loadEqCoefficients(uint8_t* buffer, size_t maxLen) {
  return prefs.getBytes("eq", buffer, maxLen);
}

void saveEqCoefficients(const uint8_t* data, size_t len) {
  prefs.putBytes("eq", data, len);
}

}  // namespace Storage
