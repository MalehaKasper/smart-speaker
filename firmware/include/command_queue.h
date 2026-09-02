#pragma once

#include <cstddef>
#include <cstdint>

// Черга команд між BLE/фізичними колбеками (можуть виконуватись у контексті
// радіостека чи апаратного переривання) і задачею, прив'язаною до Core 1,
// яка одна виконує I2C/NVS/LED-роботу. Жоден колбек не звертається до
// DspController/Display/LedStrip/Storage напряму — лише кладе команду сюди.
namespace CommandQueue {

// З запасом понад 21-байтний 0x03-payload (band_index + 5 × float32), див. build-firmware
constexpr size_t MAX_EQ_PAYLOAD_LEN = 32;

enum class CommandType : uint8_t {
  VolumeSet,
  SourceSet,
  EqCoefficients,
  EncoderRotate,
  EncoderPress,
  IrCode,
};

struct Command {
  CommandType type = CommandType::VolumeSet;
  uint8_t value = 0;             // гучність або джерело
  int8_t encoderDirection = 0;   // -1 або +1
  uint32_t irCode = 0;
  uint8_t eqData[MAX_EQ_PAYLOAD_LEN] = {};
  size_t eqLen = 0;
};

using Handler = void (*)(const Command& command);

// Створює чергу і задачу на Core 1, що читає чергу й викликає handler
void begin(Handler handler);

// Викликати з контексту, що не є апаратним перериванням (BLE-колбек, main loop)
bool send(const Command& command);

// Викликати виключно з ISR (переривання енкодера)
bool sendFromISR(const Command& command);

}  // namespace CommandQueue
