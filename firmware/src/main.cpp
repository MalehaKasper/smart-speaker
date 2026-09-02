#include <Arduino.h>

#include <cstring>

#include "audio_input.h"
#include "ble_server.h"
#include "command_queue.h"
#include "config.h"
#include "display.h"
#include "dsp_controller.h"
#include "inputs.h"
#include "led_strip.h"
#include "storage.h"

namespace {

uint8_t currentVolume = 50;
uint8_t currentSource = 0;

// Виконується виключно всередині задачі CommandQueue на Core 1 —
// єдине місце, де прошивка торкається I2C/LED/NVS.
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

void processCommand(const CommandQueue::Command& command) {
  switch (command.type) {
    case CommandQueue::CommandType::VolumeSet:
      applyVolume(command.value);
      break;
    case CommandQueue::CommandType::SourceSet:
      applySource(command.value);
      break;
    case CommandQueue::CommandType::EqCoefficients:
      DspController::loadEqCoefficients(command.eqData, command.eqLen);
      Storage::saveEqCoefficients(command.eqData, command.eqLen);
      break;
    case CommandQueue::CommandType::EncoderRotate:
      applyVolume(constrain(currentVolume + command.encoderDirection, VOLUME_MIN, VOLUME_MAX));
      BleServer::notifyVolumeChanged(currentVolume);
      break;
    case CommandQueue::CommandType::EncoderPress:
      applySource(currentSource == 0 ? 1 : 0);
      break;
    case CommandQueue::CommandType::IrCode:
      // Мапінг кодів пульта на дії визначається під час прошивки/навчання коду
      (void)command.irCode;
      break;
  }
}

// --- BLE: колбеки лише формують команду й кладуть її в чергу ---
// Викликаються NimBLE-стеком; НІКОЛИ не виконують I2C/NVS/LED-роботу самі.
void onBleVolumeSet(uint8_t volume) {
  CommandQueue::Command command;
  command.type = CommandQueue::CommandType::VolumeSet;
  command.value = volume;
  CommandQueue::send(command);
}

void onBleSourceSet(uint8_t source) {
  CommandQueue::Command command;
  command.type = CommandQueue::CommandType::SourceSet;
  command.value = source;
  CommandQueue::send(command);
}

void onBleEqCoefficients(const uint8_t* data, size_t len) {
  if (len > CommandQueue::MAX_EQ_PAYLOAD_LEN) return;  // некоректний/завеликий payload — ігнорується

  CommandQueue::Command command;
  command.type = CommandQueue::CommandType::EqCoefficients;
  memcpy(command.eqData, data, len);  // копія: вихідний буфер BLE-стека живе лише в межах onWrite
  command.eqLen = len;
  CommandQueue::send(command);
}

// --- Фізичні входи: так само, лише кладуть команду в чергу ---
void onEncoderRotate(int8_t direction) {
  CommandQueue::Command command;
  command.type = CommandQueue::CommandType::EncoderRotate;
  command.encoderDirection = direction;
  CommandQueue::send(command);  // викликається з Inputs::poll() — не ISR
}

// IRAM_ATTR: викликається напряму з апаратного переривання (onEncoderButton в
// inputs.cpp, теж IRAM_ATTR) — код, досяжний з ISR, має лишатись у IRAM.
void IRAM_ATTR onEncoderPress() {
  CommandQueue::Command command;
  command.type = CommandQueue::CommandType::EncoderPress;
  CommandQueue::sendFromISR(command);
}

void onIrCode(uint32_t code) {
  CommandQueue::Command command;
  command.type = CommandQueue::CommandType::IrCode;
  command.irCode = code;
  CommandQueue::send(command);  // викликається з Inputs::poll() — не ISR
}

}  // namespace

void setup() {
  Serial.begin(115200);

  Storage::begin();
  currentVolume = Storage::loadVolume();
  currentSource = Storage::loadSource();

  Display::begin();
  LedStrip::begin();
  DspController::begin();  // блокує до завершення Selfboot ADAU1401 — див. dsp_controller.cpp
  AudioInput::begin();

  CommandQueue::begin(processCommand);

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

  // Початкове застосування — до старту задачі черги ще нема конкуренції за I2C,
  // тож викликаємо напряму тим самим шляхом, що й processCommand().
  applyVolume(currentVolume);
  applySource(currentSource);
}

void loop() { Inputs::poll(); }
