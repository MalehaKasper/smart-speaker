import 'dart:typed_data';

/// Кодування/декодування BLE control- і notify-payload, узгоджене з
/// прошивкою (`firmware/src/ble_server.cpp`,
/// `openspec/changes/build-firmware/specs/ble-control-protocol/spec.md`).
///
/// Байтопорядок float32 у payload `0x03` — little-endian (відповідає
/// архітектурі ESP32/Xtensa). Це не було зафіксовано явно в openspec-специфікації
/// на момент написання цього коду — варто звірити з реалізацією конвертації
/// float→fixed-point у `dsp_controller.cpp`, коли вона буде дороблена.
class BleProtocol {
  BleProtocol._();

  static const int opVolume = 0x01;
  static const int opSource = 0x02;
  static const int opEqBand = 0x03;

  static const int minBandIndex = 0;
  static const int maxBandIndex = 7;

  /// `0x01 [гучність: 0-100]`
  static List<int> encodeVolume(int volume) {
    return [opVolume, volume.clamp(0, 100)];
  }

  /// `0x02 [0 = Bluetooth, 1 = AUX]`
  static List<int> encodeSource(int source) {
    return [opSource, source == 0 ? 0 : 1];
  }

  /// `0x03 [band_index: 0-7][b0][b1][b2][a1][a2]` — 5 × float32 (little-endian), разом 21 байт.
  static List<int> encodeEqBand(int bandIndex, List<double> coefficients) {
    if (bandIndex < minBandIndex || bandIndex > maxBandIndex) {
      throw ArgumentError.value(bandIndex, 'bandIndex', 'має бути 0-7');
    }
    if (coefficients.length != 5) {
      throw ArgumentError.value(coefficients, 'coefficients', 'очікує рівно 5 (b0,b1,b2,a1,a2)');
    }

    final buffer = ByteData(2 + 5 * 4);
    buffer.setUint8(0, opEqBand);
    buffer.setUint8(1, bandIndex);
    for (var i = 0; i < 5; i++) {
      buffer.setFloat32(2 + i * 4, coefficients[i], Endian.little);
    }
    return buffer.buffer.asUint8List();
  }

  /// Notify-payload `0x01 [гучність]`, який колонка надсилає після зміни
  /// гучності фізичним енкодером. Повертає `null`, якщо формат неочікуваний.
  static int? decodeVolumeNotify(List<int> data) {
    if (data.length >= 2 && data[0] == opVolume) {
      return data[1];
    }
    return null;
  }
}
