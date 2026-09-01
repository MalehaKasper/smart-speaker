#pragma once

// I2S (A2DP -> ADAU1401)
constexpr int PIN_I2S_BCLK = 26;
constexpr int PIN_I2S_LRCLK = 25;
constexpr int PIN_I2S_DOUT = 22;

// I2C (ADAU1401 + TM1650)
constexpr int PIN_I2C_SDA = 21;
constexpr int PIN_I2C_SCL = 19;
constexpr uint8_t ADAU1401_I2C_ADDR = 0x34;
constexpr uint8_t TM1650_I2C_ADDR = 0x24;

// Роторний енкодер
constexpr int PIN_ENCODER_A = 32;
constexpr int PIN_ENCODER_B = 33;
constexpr int PIN_ENCODER_BUTTON = 27;

// ІЧ-приймач
constexpr int PIN_IR_RECEIVE = 15;

// Адресна стрічка WS2812B
constexpr int PIN_LED_STRIP = 4;
constexpr int LED_STRIP_COUNT = 24;

// BLE
constexpr char BLE_DEVICE_NAME[] = "SmartSpeaker-2.1";

// Межі гучності
constexpr uint8_t VOLUME_MIN = 0;
constexpr uint8_t VOLUME_MAX = 100;
