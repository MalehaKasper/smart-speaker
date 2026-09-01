#pragma once

// A2DP Sink -> I2S міст до ADAU1401.
namespace AudioInput {

void begin();

// true, якщо зараз активне Bluetooth-з'єднання й іде трансляція звуку
bool isStreaming();

}  // namespace AudioInput
