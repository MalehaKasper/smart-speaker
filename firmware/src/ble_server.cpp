#include "ble_server.h"

#include <NimBLEDevice.h>

#include "config.h"

namespace {

constexpr char SERVICE_UUID[] = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
constexpr char CONTROL_CHAR_UUID[] = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";   // Write (App -> ESP32)
constexpr char NOTIFY_CHAR_UUID[] = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";    // Notify (ESP32 -> App)

BleServer::Callbacks callbacks;
NimBLECharacteristic* notifyChar = nullptr;

class ControlCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* characteristic) override {
    const std::string value = characteristic->getValue();
    if (value.empty()) return;

    const auto* data = reinterpret_cast<const uint8_t*>(value.data());
    const uint8_t opcode = data[0];

    switch (opcode) {
      case 0x01:
        if (value.size() >= 2 && callbacks.onVolumeSet) {
          callbacks.onVolumeSet(data[1]);
        }
        break;
      case 0x02:
        if (value.size() >= 2 && callbacks.onSourceSet) {
          callbacks.onSourceSet(data[1]);
        }
        break;
      case 0x03:
        if (callbacks.onEqCoefficients) {
          callbacks.onEqCoefficients(data + 1, value.size() - 1);
        }
        break;
      default:
        break;
    }
  }
};

ControlCallbacks controlCallbacks;

}  // namespace

namespace BleServer {

void begin(const Callbacks& cb) {
  callbacks = cb;

  NimBLEDevice::init(BLE_DEVICE_NAME);
  NimBLEServer* server = NimBLEDevice::createServer();
  NimBLEService* service = server->createService(SERVICE_UUID);

  NimBLECharacteristic* controlChar = service->createCharacteristic(
      CONTROL_CHAR_UUID, NIMBLE_PROPERTY::WRITE);
  controlChar->setCallbacks(&controlCallbacks);

  notifyChar = service->createCharacteristic(
      NOTIFY_CHAR_UUID, NIMBLE_PROPERTY::NOTIFY);

  service->start();
  server->getAdvertising()->addServiceUUID(SERVICE_UUID);
  server->getAdvertising()->start();
}

void notifyVolumeChanged(uint8_t volume) {
  if (notifyChar == nullptr) return;
  const uint8_t payload[2] = {0x01, volume};
  notifyChar->setValue(payload, sizeof(payload));
  notifyChar->notify();
}

}  // namespace BleServer
