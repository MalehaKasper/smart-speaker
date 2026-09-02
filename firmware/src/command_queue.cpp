#include "command_queue.h"

#include <esp_attr.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>

namespace {

constexpr UBaseType_t QUEUE_LENGTH = 16;
constexpr uint32_t TASK_STACK_SIZE = 4096;
constexpr UBaseType_t TASK_PRIORITY = 1;
constexpr BaseType_t CORE_1 = 1;

QueueHandle_t commandQueue = nullptr;
CommandQueue::Handler commandHandler = nullptr;

void commandTask(void*) {
  CommandQueue::Command command;
  for (;;) {
    if (xQueueReceive(commandQueue, &command, portMAX_DELAY) == pdTRUE) {
      if (commandHandler != nullptr) {
        commandHandler(command);
      }
    }
  }
}

}  // namespace

namespace CommandQueue {

void begin(Handler handler) {
  commandHandler = handler;
  commandQueue = xQueueCreate(QUEUE_LENGTH, sizeof(Command));
  xTaskCreatePinnedToCore(commandTask, "cmd_queue", TASK_STACK_SIZE, nullptr,
                           TASK_PRIORITY, nullptr, CORE_1);
}

bool send(const Command& command) {
  if (commandQueue == nullptr) return false;
  return xQueueSend(commandQueue, &command, 0) == pdTRUE;
}

// IRAM_ATTR: досяжна з апаратного переривання (через onEncoderPress в main.cpp).
bool IRAM_ATTR sendFromISR(const Command& command) {
  if (commandQueue == nullptr) return false;
  BaseType_t higherPriorityTaskWoken = pdFALSE;
  const bool ok =
      xQueueSendFromISR(commandQueue, &command, &higherPriorityTaskWoken) == pdTRUE;
  if (higherPriorityTaskWoken) portYIELD_FROM_ISR();
  return ok;
}

}  // namespace CommandQueue
