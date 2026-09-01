#pragma once

#include <cstdint>
#include <cstddef>

// I2C-майстер для ADAU1401. Всі зміни гучності та коефіцієнтів EQ
// пишуться виключно через Safeload-регістри, щоб уникнути клацань.
namespace DspController {

void begin();

void setVolume(uint8_t volume);
void setSource(uint8_t source);  // 0 = Bluetooth, 1 = AUX
void loadEqCoefficients(const uint8_t* data, size_t len);

}  // namespace DspController
