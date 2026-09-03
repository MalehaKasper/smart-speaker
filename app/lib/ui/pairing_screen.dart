import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_connection.dart';
import 'home_screen.dart';
import 'theme.dart';

/// Екран пошуку/підключення — показується лише поки MAC-адреса колонки
/// ще не збережена. Стиль — з `Smart Speaker EQ.dc.html` (Claude Design).
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  ScanResult? _connecting;

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
    setState(() => _connecting = result);
    await ref.read(deviceScanProvider.notifier).stopScan();
    await ref.read(bleConnectionProvider.notifier).connect(result.device);
    if (!mounted) return;
    final status = ref.read(bleConnectionProvider).status;
    if (status == ConnectionStatus.connected) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      setState(() => _connecting = null);
    }
  }

  int _signalBars(int rssi) {
    if (rssi >= -55) return 3;
    if (rssi >= -75) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(deviceScanProvider);
    final connectionState = ref.watch(bleConnectionProvider);
    final isConnecting = connectionState.status == ConnectionStatus.connecting;

    return Scaffold(
      backgroundColor: AppColors.screenBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                  ),
                  const SizedBox(width: 10),
                  Text('SMART SPEAKER EQ', style: AppText.mono(size: 11)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Шукаю колонку', style: AppText.display.copyWith(fontSize: 27)),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            style: AppText.body.copyWith(fontSize: 15, color: AppColors.inkSecondary, height: 1.5),
                            children: [
                              const TextSpan(text: "Скануємо пристрої з ім'ям "),
                              TextSpan(text: kSpeakerDeviceName, style: AppText.mono(size: 15, color: AppColors.ink)),
                              const TextSpan(text: '. Тримайте колонку увімкненою поруч.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.speaker_outlined, size: 56, color: AppColors.accent),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Text('СКАН · ЗНАЙДЕНО ${results.length}', style: AppText.mono(size: 11, color: AppColors.inkTertiary)),
                ],
              ),
            ),
            if (connectionState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Text(connectionState.errorMessage!, style: TextStyle(color: AppColors.red)),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text('Пристроїв поки не знайдено…', style: AppText.body.copyWith(color: AppColors.inkTertiary)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final result = results[index];
                        final bars = _signalBars(result.rssi);
                        final busy = _connecting?.device.remoteId == result.device.remoteId;
                        return InkWell(
                          onTap: isConnecting ? null : () => _connect(result),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(result.advertisementData.advName, style: AppText.body.copyWith(fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text('${result.device.remoteId.str} · ${result.rssi} dBm', style: AppText.mono(size: 11)),
                                    ],
                                  ),
                                ),
                                if (busy)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                  )
                                else
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: List.generate(3, (i) {
                                      final lit = i < bars;
                                      return Container(
                                        margin: const EdgeInsets.only(left: 3),
                                        width: 3,
                                        height: 6.0 + i * 5,
                                        color: lit ? AppColors.accent : AppColors.border,
                                      );
                                    }),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Збережена MAC-адреса', style: AppText.body.copyWith(fontSize: 13, color: AppColors.inkTertiary)),
                      Text('ПОРОЖНЯ', style: AppText.mono(size: 11, color: AppColors.red)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'MAC ЗАПАМ\'ЯТАЄТЬСЯ ДЛЯ АВТОПІДКЛЮЧЕННЯ',
                    style: AppText.mono(size: 10, color: AppColors.inkLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
