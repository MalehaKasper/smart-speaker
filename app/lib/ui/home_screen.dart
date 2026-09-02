import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_connection.dart';
import 'equalizer_screen.dart';

/// Головний екран: повзунок гучності, перемикач джерела, статус з'єднання,
/// ненав'язливе скасування останньої зміни (home-screen-controls, settings-history).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Локальне відображення під час перетягування повзунка — НЕ торкається
  // спільного стану/історії, поки користувач не відпустив палець
  // (інакше "Скасувати" відновлювало б проміжне значення, а не справжнє попереднє).
  double? _draggingVolume;

  String _statusLabel(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 'Підключено';
      case ConnectionStatus.connecting:
        return 'Підключення…';
      case ConnectionStatus.reconnecting:
        return 'Перепідключення…';
      case ConnectionStatus.scanning:
        return 'Пошук…';
      case ConnectionStatus.disconnected:
        return 'Не підключено';
    }
  }

  Future<void> _onVolumeChangeEnd(double value) async {
    await ref.read(bleConnectionProvider.notifier).setVolume(value.round());
    setState(() => _draggingVolume = null);
    if (!mounted) return;
    _showUndoSnackbar();
  }

  Future<void> _onSourceChanged(int source) async {
    await ref.read(bleConnectionProvider.notifier).setSource(source);
    if (!mounted) return;
    _showUndoSnackbar();
  }

  void _showUndoSnackbar() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Налаштування змінено'),
        action: SnackBarAction(
          label: 'Скасувати',
          onPressed: () => ref.read(bleConnectionProvider.notifier).undoLastChange(),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bleConnectionProvider);
    final connected = state.status == ConnectionStatus.connected;
    final displayedVolume = _draggingVolume ?? state.volume.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Speaker 2.1'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    size: 18,
                    color: connected ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(_statusLabel(state.status), style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text('${displayedVolume.round()}', style: Theme.of(context).textTheme.displayLarge),
            const Text('Гучність'),
            Slider(
              value: displayedVolume,
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: connected ? (value) => setState(() => _draggingVolume = value) : null,
              onChangeEnd: connected ? _onVolumeChangeEnd : null,
            ),
            const SizedBox(height: 24),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Bluetooth')),
                ButtonSegment(value: 1, label: Text('AUX')),
              ],
              selected: {state.source},
              onSelectionChanged:
                  connected ? (selection) => _onSourceChanged(selection.first) : null,
            ),
            const SizedBox(height: 32),
            Card(
              child: ListTile(
                leading: const Icon(Icons.equalizer),
                title: const Text('Еквалайзер'),
                subtitle: const Text('8 смуг · Кімнатна корекція'),
                trailing: const Icon(Icons.chevron_right),
                enabled: connected,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EqualizerScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
