import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/settings_history.dart';
import 'protocol.dart';

/// Ім'я BLE-пристрою — має збігатись з `BLE_DEVICE_NAME` у `firmware/include/config.h`.
const String kSpeakerDeviceName = 'SmartSpeaker-2.1';

/// UUID сервісу й характеристик — мають збігатись з `firmware/src/ble_server.cpp`.
final Guid kServiceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
final Guid kControlCharUuid = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e');
final Guid kNotifyCharUuid = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');

const String kPrefsMacKey = 'speaker_mac';

/// Мінімальний BLE MTU, за якого payload `0x03` (21 байт) взагалі влазить
/// (23 стандартних мінус 3 байти заголовка ATT-запису = 20 доступних байт —
/// на 1 менше за потрібне; тож ціль — щонайменше 24).
const int kMinEqMtu = 24;

enum ConnectionStatus { disconnected, scanning, connecting, connected, reconnecting }

class BleConnectionState {
  final ConnectionStatus status;
  final int volume;
  final int source; // 0 = Bluetooth, 1 = AUX
  final bool eqReady;
  final String? errorMessage;

  const BleConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.volume = 50,
    this.source = 0,
    this.eqReady = false,
    this.errorMessage,
  });

  BleConnectionState copyWith({
    ConnectionStatus? status,
    int? volume,
    int? source,
    bool? eqReady,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BleConnectionState(
      status: status ?? this.status,
      volume: volume ?? this.volume,
      source: source ?? this.source,
      eqReady: eqReady ?? this.eqReady,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Спільне джерело правди для BLE-з'єднання, гучності й джерела звуку —
/// слухають і головний екран, і екран еквалайзера (build-mobile-app design.md).
class BleConnectionNotifier extends Notifier<BleConnectionState> {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _controlChar;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  final SettingsHistoryStore _history = SettingsHistoryStore();

  @override
  BleConnectionState build() {
    ref.onDispose(() {
      _notifySub?.cancel();
      _connSub?.cancel();
    });
    return const BleConnectionState();
  }

  /// Спробувати підключитись за раніше збереженою MAC-адресою.
  /// Повертає false, якщо MAC ще не збережено — виклик має показати екран пошуку.
  Future<bool> connectToSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(kPrefsMacKey);
    if (mac == null) return false;

    state = state.copyWith(status: ConnectionStatus.connecting, clearError: true);
    try {
      final device = BluetoothDevice(remoteId: DeviceIdentifier(mac));
      await _connectAndDiscover(device);
      return true;
    } catch (_) {
      state = state.copyWith(
        status: ConnectionStatus.disconnected,
        errorMessage: 'Не вдалося підключитись до збереженої колонки',
      );
      return false;
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    state = state.copyWith(status: ConnectionStatus.connecting, clearError: true);
    try {
      await _connectAndDiscover(device);
    } catch (_) {
      state = state.copyWith(
        status: ConnectionStatus.disconnected,
        errorMessage: 'Не вдалося підключитись до колонки',
      );
    }
  }

  Future<void> _connectAndDiscover(BluetoothDevice device) async {
    _device = device;

    _connSub?.cancel();
    _connSub = device.connectionState.listen((connState) {
      if (connState == BluetoothConnectionState.disconnected &&
          state.status == ConnectionStatus.connected) {
        state = state.copyWith(status: ConnectionStatus.reconnecting, eqReady: false);
        _attemptReconnect();
      }
    });

    await device.connect(timeout: const Duration(seconds: 12));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsMacKey, device.remoteId.str);

    // MTU-негоціація — обов'язкова передумова для EQ (build-mobile-app design.md):
    // payload на смугу (21 байт) не влазить у стандартний ATT_MTU=23 без неї.
    int mtu = 23;
    try {
      mtu = await device.requestMtu(247);
    } catch (_) {
      // деякі платформи/пристрої можуть відмовити — лишаємось на стандартному MTU
    }

    final services = await device.discoverServices();
    final service = services.firstWhere((s) => s.uuid == kServiceUuid);
    _controlChar = service.characteristics.firstWhere((c) => c.uuid == kControlCharUuid);
    final notifyChar = service.characteristics.firstWhere((c) => c.uuid == kNotifyCharUuid);

    await notifyChar.setNotifyValue(true);
    _notifySub?.cancel();
    _notifySub = notifyChar.onValueReceived.listen(_onNotify);

    state = state.copyWith(status: ConnectionStatus.connected, eqReady: mtu >= kMinEqMtu);
  }

  void _onNotify(List<int> data) {
    final volume = BleProtocol.decodeVolumeNotify(data);
    if (volume != null) {
      state = state.copyWith(volume: volume);
    }
  }

  Future<void> _attemptReconnect() async {
    final device = _device;
    if (device == null) return;
    try {
      await device.connect(timeout: const Duration(seconds: 12));
      state = state.copyWith(status: ConnectionStatus.connected);
    } catch (_) {
      state = state.copyWith(status: ConnectionStatus.disconnected);
    }
  }

  /// Застосувати нову гучність: записати знімок попереднього стану в історію
  /// (для "Скасувати"), надіслати на колонку, оновити стан.
  Future<void> setVolume(int volume) async {
    final clamped = volume.clamp(0, 100);
    await _history.pushSnapshot(SettingsSnapshot(
      volume: state.volume,
      source: state.source,
      timestamp: DateTime.now(),
    ));
    await _write(BleProtocol.encodeVolume(clamped));
    state = state.copyWith(volume: clamped);
  }

  Future<void> setSource(int source) async {
    await _history.pushSnapshot(SettingsSnapshot(
      volume: state.volume,
      source: state.source,
      timestamp: DateTime.now(),
    ));
    await _write(BleProtocol.encodeSource(source));
    state = state.copyWith(source: source);
  }

  /// Скасувати останню зміну — відновити попередній знімок і надіслати на колонку.
  /// Повертає false, якщо історія порожня.
  Future<bool> undoLastChange() async {
    final snapshot = await _history.popLast();
    if (snapshot == null) return false;
    await _write(BleProtocol.encodeVolume(snapshot.volume));
    await _write(BleProtocol.encodeSource(snapshot.source));
    state = state.copyWith(volume: snapshot.volume, source: snapshot.source);
    return true;
  }

  /// Надіслати коефіцієнти однієї смуги EQ. Кидає [StateError], якщо MTU замалий.
  Future<void> sendEqBand(int bandIndex, List<double> coefficients) async {
    if (!state.eqReady) {
      throw StateError('BLE MTU замалий для відправки EQ — потрібно щонайменше $kMinEqMtu байт');
    }
    await _write(BleProtocol.encodeEqBand(bandIndex, coefficients));
  }

  Future<void> _write(List<int> bytes) async {
    final char = _controlChar;
    if (char == null) return;
    await char.write(bytes, withoutResponse: true);
  }
}

final bleConnectionProvider = NotifierProvider<BleConnectionNotifier, BleConnectionState>(
  BleConnectionNotifier.new,
);

/// Сканування BLE-пристроїв за відомим ім'ям колонки — для екрана пошуку/підключення.
class DeviceScanNotifier extends Notifier<List<ScanResult>> {
  StreamSubscription<List<ScanResult>>? _sub;

  @override
  List<ScanResult> build() {
    ref.onDispose(() => _sub?.cancel());
    return const [];
  }

  Future<void> startScan() async {
    state = const [];
    _sub?.cancel();
    _sub = FlutterBluePlus.scanResults.listen((results) {
      state = results.where((r) => r.advertisementData.advName == kSpeakerDeviceName).toList();
    });
    await FlutterBluePlus.startScan(
      withNames: [kSpeakerDeviceName],
      timeout: const Duration(seconds: 15),
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }
}

final deviceScanProvider = NotifierProvider<DeviceScanNotifier, List<ScanResult>>(
  DeviceScanNotifier.new,
);
