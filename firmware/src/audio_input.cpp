#include "audio_input.h"

#include <BluetoothA2DPSink.h>

#include "config.h"

namespace {
BluetoothA2DPSink a2dpSink;
}

namespace AudioInput {

void begin() {
  i2s_pin_config_t pinConfig = {
      .bck_io_num = PIN_I2S_BCLK,
      .ws_io_num = PIN_I2S_LRCLK,
      .data_out_num = PIN_I2S_DOUT,
      .data_in_num = I2S_PIN_NO_CHANGE,
  };
  a2dpSink.set_pin_config(pinConfig);
  a2dpSink.start(BLE_DEVICE_NAME);
}

bool isStreaming() { return a2dpSink.is_connected(); }

}  // namespace AudioInput
