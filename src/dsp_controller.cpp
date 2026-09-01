#include "dsp_controller.h"

#include <Wire.h>

#include "config.h"

namespace {

// Адреси Safeload- та цільових регістрів залежать від конкретної SigmaStudio-схеми
// і мають бути згенеровані експортом проєкту DSP (наразі — заглушки).
constexpr uint16_t REG_SAFELOAD_DATA_0 = 0x0815;
constexpr uint16_t REG_SAFELOAD_ADDRESS = 0x081C;
constexpr uint16_t REG_VOLUME_TARGET = 0x0000;
constexpr uint16_t REG_SOURCE_MUX = 0x0001;
constexpr uint16_t REG_EQ_TARGET_BASE = 0x0010;

void i2cWriteRegister(uint16_t reg, const uint8_t* data, size_t len) {
  Wire.beginTransmission(ADAU1401_I2C_ADDR);
  Wire.write(reg >> 8);
  Wire.write(reg & 0xFF);
  Wire.write(data, len);
  Wire.endTransmission();
}

// Запис через Safeload-регістри: дані спочатку вантажаться в буфер,
// потім атомарно застосовуються до цільового регістра — без клацань.
void safeload(uint16_t targetRegister, const uint8_t* data, size_t len) {
  i2cWriteRegister(REG_SAFELOAD_DATA_0, data, len);
  const uint8_t addressBytes[2] = {
      static_cast<uint8_t>(targetRegister >> 8),
      static_cast<uint8_t>(targetRegister & 0xFF),
  };
  i2cWriteRegister(REG_SAFELOAD_ADDRESS, addressBytes, sizeof(addressBytes));
}

}  // namespace

namespace DspController {

void begin() { Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL); }

void setVolume(uint8_t volume) {
  const uint8_t value = volume;
  safeload(REG_VOLUME_TARGET, &value, sizeof(value));
}

void setSource(uint8_t source) {
  const uint8_t value = source;
  safeload(REG_SOURCE_MUX, &value, sizeof(value));
}

void loadEqCoefficients(const uint8_t* data, size_t len) {
  safeload(REG_EQ_TARGET_BASE, data, len);
}

}  // namespace DspController
