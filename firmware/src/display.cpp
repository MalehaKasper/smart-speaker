#include "display.h"

#include <Wire.h>

#include "config.h"

namespace {

constexpr uint8_t DIGIT_SEGMENTS[10] = {
    0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F,
};

void writeDigit(uint8_t position, uint8_t segments) {
  Wire.beginTransmission(TM1650_I2C_ADDR + position);
  Wire.write(segments);
  Wire.endTransmission();
}

void showNumber(uint16_t value) {
  writeDigit(0, DIGIT_SEGMENTS[(value / 100) % 10]);
  writeDigit(1, DIGIT_SEGMENTS[(value / 10) % 10]);
  writeDigit(2, DIGIT_SEGMENTS[value % 10]);
}

}  // namespace

namespace Display {

void begin() { Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL); }

void showVolume(uint8_t volume) { showNumber(volume); }

void showSource(uint8_t source) {
  // "bt" / "Aux" на трисегментному дисплеї — спрощений вивід кодом джерела
  showNumber(source == 0 ? 0 : 1);
}

}  // namespace Display
