#pragma once

#include <cstdint>

// Адресна стрічка WS2812B (FastLED): бурштиновий VU-метр гучності.
namespace LedStrip {

void begin();
void showVolumeLevel(uint8_t volume);  // 0-100

}  // namespace LedStrip
