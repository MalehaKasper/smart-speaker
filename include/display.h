#pragma once

#include <cstdint>

// Екран TM1650 (I2C): вивід гучності або джерела звуку.
namespace Display {

void begin();
void showVolume(uint8_t volume);
void showSource(uint8_t source);  // 0 = Bluetooth ("bt"), 1 = AUX ("Aux")

}  // namespace Display
