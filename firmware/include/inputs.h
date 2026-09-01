#pragma once

#include <cstdint>

// Роторний енкодер (переривання) та ІЧ-приймач (IRremote).
namespace Inputs {

struct Callbacks {
  void (*onEncoderRotate)(int8_t direction);  // -1 або +1
  void (*onEncoderPress)();
  void (*onIrCode)(uint32_t code);
};

void begin(const Callbacks& callbacks);

// Викликати з loop(): обробка накопичених ІЧ-кодів (IRremote не переривання-safe)
void poll();

}  // namespace Inputs
