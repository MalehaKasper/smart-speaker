#include "inputs.h"

#include <Arduino.h>
#include <IRremote.hpp>

#include "config.h"

namespace {

Inputs::Callbacks callbacks;

volatile int8_t lastEncoderState = 0;
volatile int32_t encoderDelta = 0;

void IRAM_ATTR onEncoderChange() {
  static const int8_t transitionTable[16] = {0, -1, 1, 0, 1, 0, 0, -1,
                                              -1, 0, 0, 1, 0, 1, -1, 0};
  const uint8_t a = digitalRead(PIN_ENCODER_A);
  const uint8_t b = digitalRead(PIN_ENCODER_B);
  const uint8_t state = (a << 1) | b;
  const uint8_t index = (lastEncoderState << 2) | state;
  encoderDelta += transitionTable[index & 0x0F];
  lastEncoderState = state;
}

void IRAM_ATTR onEncoderButton() {
  if (callbacks.onEncoderPress) callbacks.onEncoderPress();
}

}  // namespace

namespace Inputs {

void begin(const Callbacks& cb) {
  callbacks = cb;

  pinMode(PIN_ENCODER_A, INPUT_PULLUP);
  pinMode(PIN_ENCODER_B, INPUT_PULLUP);
  pinMode(PIN_ENCODER_BUTTON, INPUT_PULLUP);

  attachInterrupt(digitalPinToInterrupt(PIN_ENCODER_A), onEncoderChange, CHANGE);
  attachInterrupt(digitalPinToInterrupt(PIN_ENCODER_B), onEncoderChange, CHANGE);
  attachInterrupt(digitalPinToInterrupt(PIN_ENCODER_BUTTON), onEncoderButton, FALLING);

  IrReceiver.begin(PIN_IR_RECEIVE, DISABLE_LED_FEEDBACK);
}

void poll() {
  if (encoderDelta != 0 && callbacks.onEncoderRotate) {
    noInterrupts();
    const int32_t delta = encoderDelta;
    encoderDelta = 0;
    interrupts();
    const int8_t direction = delta > 0 ? 1 : -1;
    for (int32_t i = 0; i < abs(delta); ++i) {
      callbacks.onEncoderRotate(direction);
    }
  }

  if (IrReceiver.decode()) {
    if (callbacks.onIrCode) {
      callbacks.onIrCode(IrReceiver.decodedIRData.decodedRawData);
    }
    IrReceiver.resume();
  }
}

}  // namespace Inputs
