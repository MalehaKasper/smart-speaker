#include "led_strip.h"

#include <FastLED.h>

#include "config.h"

namespace {

CRGB leds[LED_STRIP_COUNT];
const CRGB AMBER = CRGB(255, 126, 0);

}  // namespace

namespace LedStrip {

void begin() {
  FastLED.addLeds<WS2812B, PIN_LED_STRIP, GRB>(leds, LED_STRIP_COUNT);
  FastLED.setBrightness(128);
  FastLED.clear();
  FastLED.show();
}

void showVolumeLevel(uint8_t volume) {
  const uint8_t litCount = (static_cast<uint16_t>(volume) * LED_STRIP_COUNT) / 100;
  for (uint8_t i = 0; i < LED_STRIP_COUNT; ++i) {
    leds[i] = (i < litCount) ? AMBER : CRGB::Black;
  }
  FastLED.show();
}

}  // namespace LedStrip
