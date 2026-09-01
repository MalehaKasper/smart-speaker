#include <Arduino.h>

#include "audio_input.h"
#include "ble_server.h"
#include "config.h"
#include "display.h"
#include "dsp_controller.h"
#include "inputs.h"
#include "led_strip.h"
#include "storage.h"

namespace {

uint8_t currentVolume = 50;
uint8_t currentSource = 0;

void applyVolume(uint8_t volume) {
  currentVolume = constrain(volume, VOLUME_MIN, VOLUME_MAX);
  DspController::setVolume(currentVolume);
  Display::showVolume(currentVolume);
  LedStrip::showVolumeLevel(currentVolume);
  Storage::saveVolume(currentVolume);
}

void applySource(uint8_t source) {
  currentSource = source;
  DspController::setSource(currentSource);
  Display::showSource(currentSource);
  Storage::saveSource(currentSource);
}

// --- BLE: команди від додатка ---
void onBleVolumeSet(uint8_t volume) { applyVolume(volume); }
void onBleSourceSet(uint8_t source) { applySource(source); }
void onBleEqCoefficients(const uint8_t* data, size_t len) {
  DspController::loadEqCoefficients(data, len);
  Storage::saveEqCoefficients(data, len);
}

// --- Фізичні входи ---
void onEncoderRotate(int8_t direction) {
  applyVolume(constrain(currentVolume + direction, VOLUME_MIN, VOLUME_MAX));
  BleServer::notifyVolumeChanged(currentVolume);
}

void onEncoderPress() { applySource(currentSource == 0 ? 1 : 0); }

void onIrCode(uint32_t code) {
  // Мапінг кодів пульта на дії визначається під час прошивки/навчання коду
  (void)code;
}

}  // namespace

void setup() {
  Serial.begin(115200);

  Storage::begin();
  currentVolume = Storage::loadVolume();
  currentSource = Storage::loadSource();

  Display::begin();
  LedStrip::begin();
  DspController::begin();
  AudioInput::begin();

  BleServer::Callbacks bleCallbacks{
      .onVolumeSet = onBleVolumeSet,
      .onSourceSet = onBleSourceSet,
      .onEqCoefficients = onBleEqCoefficients,
  };
  BleServer::begin(bleCallbacks);

  Inputs::Callbacks inputCallbacks{
      .onEncoderRotate = onEncoderRotate,
      .onEncoderPress = onEncoderPress,
      .onIrCode = onIrCode,
  };
  Inputs::begin(inputCallbacks);

  applyVolume(currentVolume);
  applySource(currentSource);
}

void loop() { Inputs::poll(); }
