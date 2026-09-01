#pragma once

#include <cstdint>

// BLE GATT-сервер: прийом команд керування від мобільного додатка
// та відправка сповіщень про зміну гучності енкодером.
//
// Payload:
//   0x01 [значення]        — гучність (0-100)
//   0x02 [0/1]              — джерело (0 = Bluetooth, 1 = AUX)
//   0x03 [масив байтів]     — коефіцієнти біквадратних фільтрів EQ
namespace BleServer {

struct Callbacks {
  void (*onVolumeSet)(uint8_t volume);
  void (*onSourceSet)(uint8_t source);
  void (*onEqCoefficients)(const uint8_t* data, size_t len);
};

void begin(const Callbacks& callbacks);

// Сповістити додаток про зміну гучності, ініційовану фізичним енкодером
void notifyVolumeChanged(uint8_t volume);

}  // namespace BleServer
