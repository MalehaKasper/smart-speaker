import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_connection.dart';
import 'home_screen.dart';

/// Екран пошуку/підключення — показується лише поки MAC-адреса колонки
/// ще не збережена (ble-client-connection: "Пошук за ім'ям при відсутньому MAC").
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deviceScanProvider.notifier).startScan();
    });
  }

  @override
  void dispose() {
    ref.read(deviceScanProvider.notifier).stopScan();
    super.dispose();
  }

  Future<void> _connect(ScanResult result) async {
    await ref.read(deviceScanProvider.notifier).stopScan();
    await ref.read(bleConnectionProvider.notifier).connect(result.device);
    if (!mounted) return;
    final status = ref.read(bleConnectionProvider).status;
    if (status == ConnectionStatus.connected) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(deviceScanProvider);
    final connectionState = ref.watch(bleConnectionProvider);
    final isConnecting = connectionState.status == ConnectionStatus.connecting;

    return Scaffold(
      appBar: AppBar(title: const Text('Пошук колонки')),
      body: Column(
        children: [
          if (isConnecting) const LinearProgressIndicator(),
          if (connectionState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                connectionState.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Шукаємо Smart Speaker 2.1 поблизу…'),
                    ),
                  )
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final result = results[index];
                      return ListTile(
                        leading: const Icon(Icons.speaker),
                        title: Text(result.advertisementData.advName),
                        subtitle: Text(result.device.remoteId.str),
                        trailing: Text('${result.rssi} dBm'),
                        onTap: isConnecting ? null : () => _connect(result),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
