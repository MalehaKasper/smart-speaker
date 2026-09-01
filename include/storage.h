#pragma once

#include <cstdint>
#include <cstddef>

// NVS: збереження останньої гучності, джерела та коефіцієнтів EQ між перезавантаженнями.
namespace Storage {

void begin();

uint8_t loadVolume();
void saveVolume(uint8_t volume);

uint8_t loadSource();
void saveSource(uint8_t source);

size_t loadEqCoefficients(uint8_t* buffer, size_t maxLen);
void saveEqCoefficients(const uint8_t* data, size_t len);

}  // namespace Storage
